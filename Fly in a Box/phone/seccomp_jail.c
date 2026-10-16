// A stand-in for Android's app sandbox on a Linux build machine: installs a seccomp filter that answers the
// old x86_64 system calls (open, stat, access, readlink, poll, select, ...) with SIGSYS, the way Android does
// for apps, then runs the given command. Used by the runtime workflow to test flyboot before the emulator.
//   seccomp_jail <command> [arguments...]
#include <stdio.h>
#include <stddef.h>
#include <unistd.h>
#include <sys/prctl.h>
#include <linux/seccomp.h>
#include <linux/filter.h>
#include <sys/syscall.h>
int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: seccomp_jail <command> [arguments...]\n"); return 2; }
    int bad[] = {
#if defined(__x86_64__)
        SYS_open, SYS_creat, SYS_stat, SYS_lstat, SYS_access, SYS_readlink, SYS_poll, SYS_select, SYS_pipe, SYS_dup2, SYS_time,
        SYS_mkdir, SYS_rmdir, SYS_unlink, SYS_rename, SYS_link, SYS_symlink, SYS_chmod, SYS_chown, SYS_lchown, SYS_getdents,
        SYS_epoll_create, SYS_epoll_wait, SYS_eventfd, SYS_inotify_init, SYS_signalfd, SYS_alarm, SYS_pause, SYS_fork, SYS_vfork,
        SYS_utimes, SYS_futimesat, SYS_getpgrp, SYS_uselib, SYS_ustat, SYS_sysfs,
#else
        SYS_reboot, SYS_swapon,                     // no legacy calls exist on aarch64; the filter is nearly empty there
#endif
    };
    int n = sizeof bad / sizeof *bad;
    struct sock_filter f[2 * 64 + 2]; int k = 0;
    f[k++] = (struct sock_filter)BPF_STMT(BPF_LD | BPF_W | BPF_ABS, offsetof(struct seccomp_data, nr));
    for (int i = 0; i < n; i++) {
        f[k++] = (struct sock_filter)BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, bad[i], 0, 1);
        f[k++] = (struct sock_filter)BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_TRAP);
    }
    f[k++] = (struct sock_filter)BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ALLOW);
    struct sock_fprog prog = { (unsigned short)k, f };
    if (prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0)) { perror("no_new_privs"); return 1; }
    if (prctl(PR_SET_SECCOMP, SECCOMP_MODE_FILTER, &prog)) { perror("seccomp"); return 1; }
    execvp(argv[1], argv + 1); perror(argv[1]); return 1;
}
