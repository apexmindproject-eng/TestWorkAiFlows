// sigguard: a preloaded library that keeps SIGSYS deliverable. flyboot answers Android's refused system calls
// from a SIGSYS handler, but a handler only runs while the signal is not blocked: with SIGSYS blocked, the
// kernels on current phones reset it to the default action and the process dies ("exit 159"). Libraries do
// block "all signals" now and then, typically around starting a thread, so that the new thread starts with
// everything blocked (pyarrow's jemalloc does this for its background thread, whose first system call,
// set_robust_list, is one Android refuses). This library replaces pthread_sigmask and sigprocmask with versions
// that never block SIGSYS; everything else they do is unchanged. No libc symbols newer than glibc 2.17.
//   built by phone/build_runtime.sh into /opt/fly/libsigguard.so, preloaded by the app (LD_PRELOAD)
#define _GNU_SOURCE
#include <signal.h>
#include <errno.h>
#include <unistd.h>
#include <sys/syscall.h>

static int set_mask(int how, const sigset_t *set, sigset_t *old) {
    sigset_t s;
    if (set) {
        s = *set;
        if (how != SIG_UNBLOCK) sigdelset(&s, SIGSYS);
        sigdelset(&s, 32); sigdelset(&s, 33);        /* glibc's own thread-cancel and setxid signals, as glibc does */
        set = &s;
    }
    long r = syscall(SYS_rt_sigprocmask, how, set, old, 8);
    return r < 0 ? errno : 0;
}
int pthread_sigmask(int how, const sigset_t *set, sigset_t *old) { return set_mask(how, set, old); }
int sigprocmask(int how, const sigset_t *set, sigset_t *old) {
    int e = set_mask(how, set, old);
    if (e) { errno = e; return -1; }
    return 0;
}
