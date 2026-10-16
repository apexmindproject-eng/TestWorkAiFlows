// flyboot: starts glibc's dynamic loader (and through it the program) inside a process that already has a
// SIGSYS handler. Android's app sandbox answers some system calls with SIGSYS, which kills a process; a
// preloaded library would be too late, because the loader itself makes such calls before it loads anything.
// So this program, which needs no libc at all, installs the handler, maps the loader into its own address
// space the way the kernel would, and jumps to it. The handler then answers the refused calls: on x86_64
// the old forms that this glibc still uses (open, stat, access, readlink, poll, select, ...) are replaced by
// their modern "...at" forms, which the sandbox allows; anything else is logged and answered with ENOSYS.
//   usage: flyboot <ld.so> [ld.so arguments...]        e.g. flyboot ld.so --library-path ... python3 prog.py
#define _GNU_SOURCE
#include <stddef.h>
#include <stdint.h>
#include <signal.h>
#include <elf.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/mman.h>
#include <sys/syscall.h>
#include <sys/time.h>
#include <time.h>
#include <ucontext.h>
#ifndef SA_RESTORER
#define SA_RESTORER 0x04000000
#endif

static long sys6(long n, long a, long b, long c, long d, long e, long f) {
#if defined(__x86_64__)
    long r; register long r10 asm("r10") = d; register long r8 asm("r8") = e; register long r9 asm("r9") = f;
    asm volatile("syscall" : "=a"(r) : "a"(n), "D"(a), "S"(b), "d"(c), "r"(r10), "r"(r8), "r"(r9) : "rcx", "r11", "memory");
    return r;
#elif defined(__aarch64__)
    register long x8 asm("x8") = n; register long x0 asm("x0") = a; register long x1 asm("x1") = b; register long x2 asm("x2") = c;
    register long x3 asm("x3") = d; register long x4 asm("x4") = e; register long x5 asm("x5") = f;
    asm volatile("svc #0" : "+r"(x0) : "r"(x8), "r"(x1), "r"(x2), "r"(x3), "r"(x4), "r"(x5) : "memory");
    return x0;
#else
#error "x86_64 or aarch64 only"
#endif
}
#define sys1(n, a) sys6(n, (long)(a), 0, 0, 0, 0, 0)
#define sys2(n, a, b) sys6(n, (long)(a), (long)(b), 0, 0, 0, 0)
#define sys3(n, a, b, c) sys6(n, (long)(a), (long)(b), (long)(c), 0, 0, 0)
#define sys4(n, a, b, c, d) sys6(n, (long)(a), (long)(b), (long)(c), (long)(d), 0, 0)
#define sys5(n, a, b, c, d, e) sys6(n, (long)(a), (long)(b), (long)(c), (long)(d), (long)(e), 0)

void *memset(void *d, int c, size_t n) { unsigned char *p = d; while (n--) *p++ = (unsigned char)c; return d; }
void *memcpy(void *d, const void *s, size_t n) { unsigned char *p = d; const unsigned char *q = s; while (n--) *p++ = *q++; return d; }
static size_t slen(const char *s) { size_t n = 0; while (s[n]) n++; return n; }
static void out(const char *s) { sys3(SYS_write, 2, s, slen(s)); }
static void outnum(long v) {
    char b[24]; int i = 23; b[i] = 0; unsigned long u = v < 0 ? -(unsigned long)v : (unsigned long)v;
    do { b[--i] = '0' + u % 10; u /= 10; } while (u);
    if (v < 0) b[--i] = '-';
    out(b + i);
}
static void die(const char *what, long err) { out("[flyboot] "); out(what); out(" (error "); outnum(-err); out(")\n"); sys1(SYS_exit_group, 127); for (;;) {} }

/* ---- the SIGSYS handler ---- */
static int seen[1024];
static void note(int nr, const char *what) {
    if (nr < 0 || nr >= 1024 || seen[nr]++ >= 3) return;
    out("[sandbox] Android refused system call "); outnum(nr); out("; "); out(what); out("\n");
}
#if defined(__x86_64__)
static long translate(int nr, const long *a, int *done) {
    *done = 1;
    switch (nr) {
    case SYS_open:     return sys4(SYS_openat, AT_FDCWD, a[0], a[1], a[2]);
    case SYS_creat:    return sys4(SYS_openat, AT_FDCWD, a[0], O_CREAT | O_WRONLY | O_TRUNC, a[1]);
    case SYS_stat:     return sys4(SYS_newfstatat, AT_FDCWD, a[0], a[1], 0);
    case SYS_lstat:    return sys4(SYS_newfstatat, AT_FDCWD, a[0], a[1], AT_SYMLINK_NOFOLLOW);
    case SYS_access:   return sys3(SYS_faccessat, AT_FDCWD, a[0], a[1]);
    case SYS_readlink: return sys4(SYS_readlinkat, AT_FDCWD, a[0], a[1], a[2]);
    case SYS_mkdir:    return sys3(SYS_mkdirat, AT_FDCWD, a[0], a[1]);
    case SYS_rmdir:    return sys3(SYS_unlinkat, AT_FDCWD, a[0], AT_REMOVEDIR);
    case SYS_unlink:   return sys3(SYS_unlinkat, AT_FDCWD, a[0], 0);
    case SYS_rename:   return sys4(SYS_renameat, AT_FDCWD, a[0], AT_FDCWD, a[1]);
    case SYS_link:     return sys5(SYS_linkat, AT_FDCWD, a[0], AT_FDCWD, a[1], 0);
    case SYS_symlink:  return sys3(SYS_symlinkat, a[0], AT_FDCWD, a[1]);
    case SYS_chmod:    return sys3(SYS_fchmodat, AT_FDCWD, a[0], a[1]);
    case SYS_chown:    return sys5(SYS_fchownat, AT_FDCWD, a[0], a[1], a[2], 0);
    case SYS_lchown:   return sys5(SYS_fchownat, AT_FDCWD, a[0], a[1], a[2], AT_SYMLINK_NOFOLLOW);
    case SYS_mknod:    return sys4(SYS_mknodat, AT_FDCWD, a[0], a[1], a[2]);
    case SYS_pipe:     return sys2(SYS_pipe2, a[0], 0);
    case SYS_dup2:
        if (a[0] == a[1]) { long r = sys2(SYS_fcntl, a[0], F_GETFD); return r < 0 ? r : a[1]; }
        return sys3(SYS_dup3, a[0], a[1], 0);
    case SYS_poll: {
        struct timespec ts, *tp = 0;
        if (a[2] >= 0) { ts.tv_sec = a[2] / 1000; ts.tv_nsec = (a[2] % 1000) * 1000000L; tp = &ts; }
        return sys5(SYS_ppoll, a[0], a[1], tp, 0, 8);
    }
    case SYS_select: {
        struct timeval *tv = (struct timeval *)a[4]; struct timespec ts, *tp = 0;
        if (tv) { ts.tv_sec = tv->tv_sec; ts.tv_nsec = tv->tv_usec * 1000; tp = &ts; }
        long r = sys6(SYS_pselect6, a[0], a[1], a[2], a[3], (long)tp, 0);
        if (tv) { tv->tv_sec = ts.tv_sec; tv->tv_usec = ts.tv_nsec / 1000; }
        return r;
    }
    case SYS_epoll_create: return sys1(SYS_epoll_create1, 0);
    case SYS_epoll_wait:   return sys6(SYS_epoll_pwait, a[0], a[1], a[2], a[3], 0, 8);
    case SYS_eventfd:      return sys2(SYS_eventfd2, a[0], 0);
    case SYS_inotify_init: return sys1(SYS_inotify_init1, 0);
    case SYS_signalfd:     return sys4(SYS_signalfd4, a[0], a[1], a[2], 0);
    case SYS_fork: case SYS_vfork: return sys5(SYS_clone, SIGCHLD, 0, 0, 0, 0);
    case SYS_getpgrp:      return sys1(SYS_getpgid, 0);
    case SYS_utimes: case SYS_futimesat: {
        int off = nr == SYS_futimesat ? 1 : 0; long dirfd = off ? a[0] : AT_FDCWD;
        struct timeval *tv = (struct timeval *)a[off + 1]; struct timespec ts[2], *tp = 0;
        if (tv) { for (int i = 0; i < 2; i++) { ts[i].tv_sec = tv[i].tv_sec; ts[i].tv_nsec = tv[i].tv_usec * 1000; } tp = ts; }
        return sys4(SYS_utimensat, dirfd, a[off], tp, 0);
    }
    case SYS_time: {
        struct timespec ts; long r = sys2(SYS_clock_gettime, CLOCK_REALTIME, &ts);
        if (r < 0) return r;
        if (a[0]) *(time_t *)a[0] = ts.tv_sec;
        return ts.tv_sec;
    }
    case SYS_alarm: {
        struct itimerval nv, ov; memset(&nv, 0, sizeof nv); nv.it_value.tv_sec = a[0];
        long r = sys3(SYS_setitimer, ITIMER_REAL, &nv, &ov);
        return r < 0 ? r : ov.it_value.tv_sec + (ov.it_value.tv_usec ? 1 : 0);
    }
    case SYS_pause: {
        unsigned long cur = 0; sys4(SYS_rt_sigprocmask, SIG_BLOCK, 0, &cur, 8);
        return sys2(SYS_rt_sigsuspend, &cur, 8);
    }
    }
    *done = 0; return -ENOSYS;
}
#endif
static void on_sigsys(int sig, siginfo_t *si, void *ucv) {
    ucontext_t *uc = (ucontext_t *)ucv; int nr = si->si_syscall; (void)sig;
#if defined(__x86_64__)
    long a[6] = { uc->uc_mcontext.gregs[REG_RDI], uc->uc_mcontext.gregs[REG_RSI], uc->uc_mcontext.gregs[REG_RDX],
                  uc->uc_mcontext.gregs[REG_R10], uc->uc_mcontext.gregs[REG_R8],  uc->uc_mcontext.gregs[REG_R9] };
    int done; long r = translate(nr, a, &done);
    note(nr, done ? "answered it with its modern equivalent" : "continuing as if it did not exist");
    uc->uc_mcontext.gregs[REG_RAX] = r;
#else
    note(nr, "continuing as if it did not exist");
    uc->uc_mcontext.regs[0] = -ENOSYS;
#endif
}
#if defined(__x86_64__)
__attribute__((naked)) static void restorer(void) { asm volatile("mov $15, %eax\n\tsyscall"); }   /* rt_sigreturn */
#endif
struct ksigaction { void (*handler)(int, siginfo_t *, void *); unsigned long flags; void (*restorer)(void); unsigned long mask; };
static void install(void) {
    struct ksigaction sa; memset(&sa, 0, sizeof sa);
    sa.handler = on_sigsys; sa.flags = SA_SIGINFO | SA_NODEFER | SA_RESTART;
#if defined(__x86_64__)
    sa.flags |= SA_RESTORER; sa.restorer = restorer;
#endif
    long r = sys4(SYS_rt_sigaction, SIGSYS, &sa, 0, 8);
    if (r < 0) die("cannot install the SIGSYS handler", r);
}

/* ---- mapping the loader ---- */
#define PAGE 4096UL
#define DOWN(x) ((x) & ~(PAGE - 1))
#define UP(x) (((x) + PAGE - 1) & ~(PAGE - 1))
static unsigned long load(const char *path, unsigned long *phdr, unsigned long *phnum) {
    long fd = sys3(SYS_openat, AT_FDCWD, path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) die("cannot open the loader", fd);
    Elf64_Ehdr eh; long r = sys4(SYS_pread64, fd, &eh, sizeof eh, 0);
    if (r != sizeof eh || eh.e_ident[0] != 0x7f || eh.e_ident[1] != 'E' || eh.e_phnum > 64) die("not an ELF file", -ENOEXEC);
    Elf64_Phdr ph[64]; r = sys4(SYS_pread64, fd, ph, eh.e_phnum * sizeof(Elf64_Phdr), eh.e_phoff);
    if (r != (long)(eh.e_phnum * sizeof(Elf64_Phdr))) die("cannot read program headers", r);
    unsigned long lo = ~0UL, hi = 0;
    for (int i = 0; i < eh.e_phnum; i++) if (ph[i].p_type == PT_LOAD) {
        if (DOWN(ph[i].p_vaddr) < lo) lo = DOWN(ph[i].p_vaddr);
        if (ph[i].p_vaddr + ph[i].p_memsz > hi) hi = ph[i].p_vaddr + ph[i].p_memsz;
    }
    long want = eh.e_type == ET_EXEC ? (long)lo : 0;
    long base = sys6(SYS_mmap, want, UP(hi) - lo, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS | (want ? MAP_FIXED : 0), -1, 0);
    if (base < 0 && base > -4096) die("cannot reserve address space", base);
    base -= lo;
    for (int i = 0; i < eh.e_phnum; i++) if (ph[i].p_type == PT_LOAD) {
        int prot = (ph[i].p_flags & PF_R ? PROT_READ : 0) | (ph[i].p_flags & PF_W ? PROT_WRITE : 0) | (ph[i].p_flags & PF_X ? PROT_EXEC : 0);
        unsigned long start = base + DOWN(ph[i].p_vaddr), fend = base + ph[i].p_vaddr + ph[i].p_filesz, mend = base + ph[i].p_vaddr + ph[i].p_memsz;
        if (fend > start) {
            r = sys6(SYS_mmap, start, fend - start, prot, MAP_PRIVATE | MAP_FIXED, fd, DOWN(ph[i].p_offset));
            if (r < 0 && r > -4096) die("cannot map a segment", r);
        }
        if (mend > fend) {                                   /* zero-filled tail (bss) */
            if (fend & (PAGE - 1)) {
                if (!(prot & PROT_WRITE)) sys3(SYS_mprotect, DOWN(fend), PAGE, prot | PROT_WRITE);
                memset((void *)fend, 0, UP(fend) - fend);
                if (!(prot & PROT_WRITE)) sys3(SYS_mprotect, DOWN(fend), PAGE, prot);
            }
            if (mend > UP(fend)) {
                r = sys6(SYS_mmap, UP(fend), mend - UP(fend), prot, MAP_PRIVATE | MAP_FIXED | MAP_ANONYMOUS, -1, 0);
                if (r < 0 && r > -4096) die("cannot map a zero segment", r);
            }
        }
    }
    sys1(SYS_close, fd);
    *phdr = base + eh.e_phoff; *phnum = eh.e_phnum;
    return base + eh.e_entry;
}

__attribute__((noreturn, used)) static void boot(long *sp) {
    long argc = sp[0]; char **argv = (char **)(sp + 1);
    if (argc < 2) { out("usage: flyboot <ld.so> [arguments...]\n"); sys1(SYS_exit_group, 2); }
    install();
    unsigned long phdr, phnum; unsigned long entry = load(argv[1], &phdr, &phnum);
    /* the new initial stack: the kernel's one without argv[0], auxv describing the loader; strings stay where they are */
    long *p = sp; long n = 1 + argc + 1;                     /* argc, argv..., NULL */
    while (p[n]) n++;                                        /* envp... */
    n++;                                                     /* and its NULL */
    Elf64_auxv_t *aux = (Elf64_auxv_t *)(p + n); long naux = 0;
    while (aux[naux].a_type != AT_NULL) naux++;
    naux++;
    long *nsp = (long *)(((unsigned long)sp - 16) & ~15UL);  /* one slot shorter: fits below the old block */
    long *q = nsp; *q++ = argc - 1;
    for (long i = 1; i <= argc; i++) *q++ = (long)argv[i];   /* argv[1..] and the NULL */
    for (long i = 1 + argc + 1; i < n; i++) *q++ = p[i];     /* envp and its NULL */
    Elf64_auxv_t *naux_p = (Elf64_auxv_t *)q;
    for (long i = 0; i < naux; i++) {
        Elf64_auxv_t e = aux[i];
        switch (e.a_type) {
        case AT_PHDR: e.a_un.a_val = phdr; break;
        case AT_PHENT: e.a_un.a_val = sizeof(Elf64_Phdr); break;
        case AT_PHNUM: e.a_un.a_val = phnum; break;
        case AT_ENTRY: e.a_un.a_val = entry; break;
        case AT_BASE: e.a_un.a_val = 0; break;
        case AT_EXECFN: e.a_un.a_val = (unsigned long)argv[1]; break;
        }
        naux_p[i] = e;
    }
#if defined(__x86_64__)
    asm volatile("mov %0, %%rsp\n\txor %%edx, %%edx\n\tjmp *%%rcx" : : "r"(nsp), "c"(entry) : "memory");
#else
    register long x16 asm("x16") = (long)entry; register long x17 asm("x17") = (long)nsp;
    asm volatile("mov sp, x17\n\tmov x0, #0\n\tbr x16" : : "r"(x16), "r"(x17) : "memory");
#endif
    for (;;) {}
}
#if defined(__x86_64__)
asm(".text\n.global _start\n_start:\n\tmov %rsp, %rdi\n\tand $-16, %rsp\n\tsub $65536, %rsp\n\tcall boot\n\thlt\n");
#else
asm(".text\n.global _start\n_start:\n\tmov x0, sp\n\tsub sp, sp, #65536\n\tbl boot\n\tbrk #0\n");
#endif
