/*
 * Phase 9 copy of the Phase 8 harness (tools/selinux/qemu/init.c, left unchanged) with two extra switches for the audit
 * investigation:
 *   gvratelimit=off  before loading the policy, set kernel.printk_ratelimit=0 (no throttling of printk), so the kernel's own
 *                    audit-to-printk path (audit_printk_skb) is not rate limited. No audit rule or policy is touched.
 *   gvaudit=netlink  register this process as the audit daemon (NETLINK_AUDIT, audit_pid) so records are queued to a socket,
 *                    as Android's logd does, instead of going through printk; at the end print what was received.
 *   gvmode=epoll     (no policy) binder use-after-free probe: an epoll watch on a binder fd, BINDER_THREAD_EXIT, close the epoll fd, then
 *                    allocate fresh binder threads. Run with slub_debug=FZPU: a stale write into the freed thread is reported as
 *                    'Poison overwritten' / 'Padding overwritten' when the object is reused.
 *   gvklog=1         at the end read the kernel ring buffer with syslog(2) and count audit lines and 'audit_lost'.
 *
 * Phase 8 QEMU test harness ("/init" of a tiny initramfs). Freestanding ARM EABI code: raw system calls, no C library.
 * It loads a compiled SELinux policy into the running kernel and then checks, with real processes, what the kernel
 * enforces. Emulator only; never runs on a phone.
 *
 * Kernel command line switches:
 *   gvmode=load      load the policy (enforcing off unless gvenforce=1), print versions, stop.
 *   gvmode=tests     set enforcing, load the policy, run the test matrix.
 *   gvexp=hooks|nohooks   which binder expectation to print PASS/FAIL against (the kernel with or without hook calls).
 *
 * Every test child switches its SELinux domain by writing to /proc/self/attr/current, performs ONE operation, and
 * reports through its exit status (a pipe would be subject to the very policy under test).
 */
typedef unsigned int u32;
typedef unsigned long ul;

#define SYS_exit 1
#define SYS_fork 2
#define SYS_read 3
#define SYS_write 4
#define SYS_open 5
#define SYS_close 6
#define SYS_mknod 14
#define SYS_syslog 103
#define SYS_epoll_create 250
#define SYS_epoll_ctl 251
#define SYS_bind 282
#define SYS_sendto 290
#define SYS_recvfrom 292
#define SYS_getpid 20
#define SYS_mprotect 125
#define SYS_setgroups32 206
#define SYS_mkdir 39
#define SYS_ioctl 54
#define SYS_mount 21
#define SYS_reboot 88
#define SYS_wait4 114
#define SYS_nanosleep 162
#define SYS_mmap2 192
#define SYS_socket 281

static long sc(long n, long a, long b, long c, long d, long e, long f) {
    register long r7 __asm__("r7") = n;
    register long r0 __asm__("r0") = a;
    register long r1 __asm__("r1") = b;
    register long r2 __asm__("r2") = c;
    register long r3 __asm__("r3") = d;
    register long r4 __asm__("r4") = e;
    register long r5 __asm__("r5") = f;
    __asm__ volatile("svc 0" : "+r"(r0) : "r"(r7), "r"(r1), "r"(r2), "r"(r3), "r"(r4), "r"(r5) : "memory");
    return r0;
}
void *memset(void *s, int c, ul n) { unsigned char *p = s; while (n--) *p++ = (unsigned char)c; return s; }
void *memcpy(void *d, const void *s, ul n) { unsigned char *a = d; const unsigned char *b = s; while (n--) *a++ = *b++; return d; }
static ul slen(const char *s) { ul n = 0; while (s[n]) n++; return n; }

static void out(const char *s) { sc(SYS_write, 1, (long)s, slen(s), 0, 0, 0); }
static void outn(long v) {
    char b[16]; int i = 15; int neg = v < 0; b[i] = 0; if (neg) v = -v;
    if (v == 0) b[--i] = '0';
    while (v > 0) { b[--i] = '0' + (v % 10); v /= 10; }
    if (neg) b[--i] = '-';
    out(b + i);
}
static int has(const char *hay, const char *needle) {
    ul n = slen(needle);
    for (; *hay; hay++) { ul i = 0; while (i < n && hay[i] == needle[i]) i++; if (i == n) return 1; }
    return 0;
}
static void msleep(long ms) { long ts[2] = { ms / 1000, (ms % 1000) * 1000000L }; sc(SYS_nanosleep, (long)ts, 0, 0, 0, 0, 0); }

static char pol[4 * 1024 * 1024];
static char scratch[4096];

static long readfile(const char *path, char *buf, ul max) {
    long fd = sc(SYS_open, (long)path, 0, 0, 0, 0, 0);
    if (fd < 0) return fd;
    long n = sc(SYS_read, fd, (long)buf, max - 1, 0, 0, 0);
    sc(SYS_close, fd, 0, 0, 0, 0, 0);
    if (n >= 0) buf[n] = 0;
    return n;
}
static long writefile(const char *path, const char *s) {
    long fd = sc(SYS_open, (long)path, 1, 0, 0, 0, 0);
    if (fd < 0) return fd;
    long n = sc(SYS_write, fd, (long)s, slen(s), 0, 0, 0);
    sc(SYS_close, fd, 0, 0, 0, 0, 0);
    return n;
}
static void show(const char *label, const char *path) {
    long n = readfile(path, scratch, sizeof scratch);
    out(label); out(": ");
    if (n < 0) { out("read failed errno="); outn(-n); out("\n"); return; }
    for (long i = 0; i < n; i++) if (scratch[i] == '\n') scratch[i] = ' ';
    out(scratch); out("\n");
}

/* ---- test matrix ---- */
enum { K_IOCTL, K_CTXMGR, K_TX_PLAIN, K_TX_BINDER, K_TX_HANDLE, K_TX_FD, K_EXECMOD };
struct test { const char *name; const char *dom; int kind; u32 cmd; int exp_hooks; int exp_nohooks; };

#define OK 0
#define EACCES_ 13
#define FAILED 77           /* BR_FAILED_REPLY seen */
#define DELIVERED 0         /* BR_TRANSACTION_COMPLETE seen */

/* socket ioctl numbers (asm-generic/sockios.h) */
#define SIOCGIFFLAGS_ 0x8913
#define SIOCGIFMETRIC_ 0x891d
#define SIOCGIFHWADDR_ 0x8927
#define SIOCGIFINDEX_ 0x8933

static const struct test tests[] = {
    /* ---- ioctl extended permissions, real Android rules ---- */
    { "xperm untrusted_app allowed cmd SIOCGIFFLAGS (in unpriv list)",   "u:r:untrusted_app:s0", K_IOCTL, SIOCGIFFLAGS_,  OK,       OK },
    { "xperm untrusted_app allowed cmd SIOCGIFINDEX (in unpriv list)",   "u:r:untrusted_app:s0", K_IOCTL, SIOCGIFINDEX_,  OK,       OK },
    { "xperm untrusted_app DENIED  cmd SIOCGIFHWADDR (priv list)",       "u:r:untrusted_app:s0", K_IOCTL, SIOCGIFHWADDR_, EACCES_,  EACCES_ },
    { "xperm untrusted_app DENIED  cmd SIOCGIFMETRIC (priv list)",       "u:r:untrusted_app:s0", K_IOCTL, SIOCGIFMETRIC_, EACCES_,  EACCES_ },
    { "xperm priv_app      allowed cmd SIOCGIFHWADDR (own rule)",        "u:r:priv_app:s0",      K_IOCTL, SIOCGIFHWADDR_, OK,       OK },
    { "xperm priv_app      DENIED  cmd SIOCGIFMETRIC (priv list)",       "u:r:priv_app:s0",      K_IOCTL, SIOCGIFMETRIC_, EACCES_,  EACCES_ },
    /* controls: same ioctl permission, no allowxperm rule -> nothing filtered */
    { "control gv_noxperm  allowed cmd SIOCGIFHWADDR (no xperm rule)",   "u:r:gv_noxperm:s0",    K_IOCTL, SIOCGIFHWADDR_, OK,       OK },
    { "control gv_noxperm  allowed cmd SIOCGIFMETRIC (no xperm rule)",   "u:r:gv_noxperm:s0",    K_IOCTL, SIOCGIFMETRIC_, OK,       OK },
    /* ---- binder hook 5: set_context_mgr ---- */
    { "binder set_context_mgr priv_app (policy forbids)",                "u:r:priv_app:s0",      K_CTXMGR, 0,             EACCES_,  OK },
    { "binder set_context_mgr servicemanager (policy allows)",           "u:r:servicemanager:s0", K_CTXMGR, 0,            OK,       OK },
    /* ---- binder hooks 1, 2, 3, 4: a context manager (servicemanager domain) is started first ---- */
    { "binder transaction gv_nocall  (no binder:call)",                  "u:r:gv_nocall:s0",     K_TX_PLAIN, 0,           FAILED,   DELIVERED },
    { "binder transaction gv_callonly (binder:call)",                    "u:r:gv_callonly:s0",   K_TX_PLAIN, 0,           DELIVERED, DELIVERED },
    { "binder transaction priv_app (real policy allows call)",           "u:r:priv_app:s0",      K_TX_PLAIN, 0,           DELIVERED, DELIVERED },
    { "binder transfer-binder gv_callonly (no binder:transfer)",         "u:r:gv_callonly:s0",   K_TX_BINDER, 0,          FAILED,   DELIVERED },
    { "binder transfer-binder gv_calltransfer (call+transfer)",          "u:r:gv_calltransfer:s0", K_TX_BINDER, 0,        DELIVERED, DELIVERED },
    { "binder transfer-handle gv_callonly (no binder:transfer)",         "u:r:gv_callonly:s0",   K_TX_HANDLE, 0,          FAILED,   DELIVERED },
    { "binder transfer-handle gv_calltransfer (call+transfer)",          "u:r:gv_calltransfer:s0", K_TX_HANDLE, 0,        DELIVERED, DELIVERED },
};


/* execmod tests (gvmode=execmod, policy with the proposed libgal_file type): a text-relocation-like sequence on a file the
 * domain itself created: map it private+writable, modify a page (copy on write), then make it executable again. */
static const struct test extests[] = {
    { "execmod gv_em_ok    file labelled libgal_file, domain has execmod on libgal_file",  "u:r:gv_em_ok:s0",    K_EXECMOD, 0, OK,      OK },
    { "execmod gv_em_no    file labelled libgal_file, domain has NO execmod",              "u:r:gv_em_no:s0",    K_EXECMOD, 0, EACCES_, EACCES_ },
    { "execmod gv_em_other file labelled gv_em_file; execmod only on libgal_file",         "u:r:gv_em_other:s0", K_EXECMOD, 1, EACCES_, EACCES_ },
};

struct bwr { long write_size, write_consumed; ul write_buffer; long read_size, read_consumed; ul read_buffer; };
struct btd { u32 target, cookie, code, flags, pid, uid, data_size, offsets_size; ul buffer, offsets; };
struct fbo { u32 type, flags, binder_or_handle, cookie; };

#define BINDER_WRITE_READ_ 0xC0186201u
#define BINDER_SET_CONTEXT_MGR_ 0x40046207u
#define BC_TRANSACTION_ 0x40286300u
#define BC_ACQUIRE_ 0x40046305u
#define BR_TRANSACTION_COMPLETE_ 0x7206u
#define BR_FAILED_REPLY_ 0x7211u
#define BR_DEAD_REPLY_ 0x7205u
#define T_BINDER 0x73622a85u
#define T_HANDLE 0x73682a85u
#define T_FD     0x66642a85u

static int setcon(const char *ctx) {
    long fd = sc(SYS_open, (long)"/proc/self/attr/current", 1, 0, 0, 0, 0);
    if (fd < 0) return -1;
    long n = sc(SYS_write, fd, (long)ctx, slen(ctx), 0, 0, 0);
    sc(SYS_close, fd, 0, 0, 0, 0, 0);
    return n < 0 ? -1 : 0;
}

static int child_body(const struct test *t) {
    /* The kernel's ANDROID_PARANOID_NETWORK check lets a process create sockets only if it is in group 3003 (AID_INET)
     * or has CAP_NET_RAW. Real apps are in group 3003. Join it BEFORE changing domain, as zygote does for apps. */
    { u32 g = 3003; sc(SYS_setgroups32, 1, (long)&g, 0, 0, 0, 0); }
    if (setcon(t->dom) < 0) return 99;
    if (t->kind == K_EXECMOD) {
        /* The files were created and labelled by the harness (kernel domain) before the domain switch, like a library file
         * on /system: the domain may only read and execute it. cmd 0 = file labelled libgal_file, 1 = labelled gv_em_file. */
        long fd = sc(SYS_open, (long)(t->cmd ? "/tmp/gvlib-other" : "/tmp/gvlib-libgal"), 0 /* O_RDONLY */, 0, 0, 0, 0);
        if (fd < 0) return 100 + (int)(-fd & 0x1f);
        long m = sc(SYS_mmap2, 0, 4096, 3, 2, fd, 0);                    /* PROT_READ|PROT_WRITE, MAP_PRIVATE (allowed on a read-only fd) */
        if (m < 0 && m > -4096) return 120 + (int)(-m & 0x1f);
        *(volatile char *)m = 1;                                           /* copy-on-write: the mapping is now modified */
        long r = sc(SYS_mprotect, m, 4096, 5, 0, 0, 0);                    /* PROT_READ|PROT_EXEC: the text-relocation step */
        return r < 0 ? (int)-r : 0;
    }
    if (t->kind == K_IOCTL) {
        long s = sc(SYS_socket, 2, 2, 0, 0, 0, 0);               /* AF_INET, SOCK_DGRAM */
        if (s < 0) return 100 + (int)(-s & 0x1f);
        char ifr[64]; memset(ifr, 0, sizeof ifr); ifr[0] = 'l'; ifr[1] = 'o';
        long r = sc(SYS_ioctl, s, t->cmd, (long)ifr, 0, 0, 0);
        return r < 0 ? (int)-r : 0;
    }
    long fd = sc(SYS_open, (long)"/dev/gvbinder", 2, 0, 0, 0, 0);
    if (fd < 0) return 130 + (int)(-fd & 0x1f);
    if (t->kind == K_CTXMGR) {
        long z = 0; long r = sc(SYS_ioctl, fd, BINDER_SET_CONTEXT_MGR_, (long)&z, 0, 0, 0);
        return r < 0 ? (int)-r : 0;
    }
    /* transactions to the context manager (handle 0) */
    static unsigned char rbuf[256];
    struct bwr bw;
    if (t->kind == K_TX_HANDLE) {                                  /* first obtain a reference to handle 0 */
        u32 w[2] = { BC_ACQUIRE_, 0 };
        memset(&bw, 0, sizeof bw); bw.write_size = sizeof w; bw.write_buffer = (ul)w;
        sc(SYS_ioctl, fd, BINDER_WRITE_READ_, (long)&bw, 0, 0, 0);
    }
    struct fbo obj; u32 payload[2] = { 1, 2 }; u32 off = 0; u32 mark = 0;
    memset(&obj, 0, sizeof obj);
    struct btd tr; memset(&tr, 0, sizeof tr);
    tr.target = 0; tr.flags = 1;                                   /* TF_ONE_WAY */
    if (t->kind == K_TX_PLAIN) { tr.data_size = sizeof payload; tr.buffer = (ul)payload; }
    else {
        if (t->kind == K_TX_BINDER) { obj.type = T_BINDER; obj.binder_or_handle = (u32)&mark; obj.cookie = (u32)&mark; obj.flags = 0x7f; }
        if (t->kind == K_TX_HANDLE) { obj.type = T_HANDLE; obj.binder_or_handle = 0; }
        if (t->kind == K_TX_FD) {
            long nf = sc(SYS_open, (long)"/dev/gvnull", 2, 0, 0, 0, 0);
            if (nf < 0) return 160;
            obj.type = T_FD; obj.binder_or_handle = (u32)nf;
        }
        tr.data_size = sizeof obj; tr.buffer = (ul)&obj; tr.offsets_size = sizeof off; tr.offsets = (ul)&off;
    }
    struct { u32 cmd; struct btd tr; } wr; wr.cmd = BC_TRANSACTION_; wr.tr = tr;
    memset(&bw, 0, sizeof bw);
    bw.write_size = sizeof wr; bw.write_buffer = (ul)&wr; bw.read_size = sizeof rbuf; bw.read_buffer = (ul)rbuf;
    long r = sc(SYS_ioctl, fd, BINDER_WRITE_READ_, (long)&bw, 0, 0, 0);
    if (r < 0) return 170 + (int)(-r & 0x1f);
    for (long i = 0; i + 4 <= bw.read_consumed; i += 4) {
        u32 c = *(u32 *)(rbuf + i);
        if (c == BR_TRANSACTION_COMPLETE_) return DELIVERED;
        if (c == BR_FAILED_REPLY_) return FAILED;
        if (c == BR_DEAD_REPLY_) return 78;
    }
    return 79;
}

static long run_child(const struct test *t) {
    long pid = sc(SYS_fork, 0, 0, 0, 0, 0, 0);
    if (pid == 0) { sc(SYS_exit, child_body(t), 0, 0, 0, 0, 0); for (;;) ; }
    if (pid < 0) return -1000;
    int st = 0; long wr = sc(SYS_wait4, pid, (long)&st, 0, 0, 0, 0);
    if (wr != pid) { out("  (wait4 returned "); outn(wr); out(", expected "); outn(pid); out(")\n"); return 250; }
    if (st & 0x7f) return 200 + (st & 0x7f);          /* killed by a signal: do not mistake it for exit status 0 */
    return (st >> 8) & 0xff;
}

static long start_ctxmgr(void) {         /* a servicemanager-domain process that stays alive for a few seconds */
    long pid = sc(SYS_fork, 0, 0, 0, 0, 0, 0);
    if (pid == 0) {
        int code = 0;
        if (setcon("u:r:servicemanager:s0") < 0) code = 99;
        else {
            long fd = sc(SYS_open, (long)"/dev/gvbinder", 2, 0, 0, 0, 0);
            if (fd < 0) code = 130 + (int)(-fd & 0x1f);
            else {
                long m = sc(SYS_mmap2, 0, 0x20000, 1, 2, fd, 0);           /* PROT_READ, MAP_PRIVATE */
                if (m < 0 && m > -4096) code = 140 + (int)(-m & 0x1f);
                else { long z = 0; long r = sc(SYS_ioctl, fd, BINDER_SET_CONTEXT_MGR_, (long)&z, 0, 0, 0); if (r < 0) code = 150 + (int)(-r & 0x1f); }
                if (code == 0) msleep(6000);
            }
        }
        sc(SYS_exit, code, 0, 0, 0, 0, 0); for (;;) ;
    }
    return pid;
}


/* Create /dev/gvbinder and /dev/gvnull with the SELinux types the Android policy expects (binder_device, null_device).
 * devtmpfs labels its own nodes `device`, which the policy does not allow; the label of a node created by mknod can be
 * chosen with /proc/self/attr/fscreate (this process runs in the permissive kernel domain). No policy is changed. */
static int parse_misc_minor(const char *name) {
    long n = readfile("/proc/misc", scratch, sizeof scratch);
    if (n <= 0) return -1;
    ul l = slen(name);
    for (long i = 0; i < n; ) {
        long j = i; int minor = 0, have = 0;
        while (j < n && scratch[j] == ' ') j++;
        while (j < n && scratch[j] >= '0' && scratch[j] <= '9') { minor = minor * 10 + (scratch[j] - '0'); have = 1; j++; }
        while (j < n && scratch[j] == ' ') j++;
        ul k = 0; while (k < l && j + (long)k < n && scratch[j + k] == name[k]) k++;
        if (have && k == l && (j + (long)k >= n || scratch[j + k] == '\n')) return minor;
        while (i < n && scratch[i] != '\n') i++;
        i++;
    }
    return -1;
}
static void make_node(const char *path, int major, int minor, const char *type_ctx) {
    writefile("/proc/self/attr/fscreate", type_ctx);
    long r = sc(SYS_mknod, (long)path, 020666, (major << 8) | minor, 0, 0, 0);
    writefile("/proc/self/attr/fscreate", "");
    out("mknod "); out(path); out(": "); outn(r); out("\n");
}


/* ---- hook 4 (transfer_file): needs a target node that accepts file descriptors ----
 * A (servicemanager domain) is the context manager. C (domain under test) sends A a node flagged ACCEPTS_FDS; A then
 * sends C an open file descriptor. The hook checks A -> C (binder transfer, fd:use of A's file for C, file access). */
#define O_RDWR_NONBLOCK 04002
#define BR_TRANSACTION_ 0x80287202u
static int fd_scenario_A(void) {
    if (setcon("u:r:servicemanager:s0") < 0) return 99;
    long fd = sc(SYS_open, (long)"/dev/gvbinder", O_RDWR_NONBLOCK, 0, 0, 0, 0);
    if (fd < 0) return 130 + (int)(-fd & 0x1f);
    long m = sc(SYS_mmap2, 0, 0x20000, 1, 2, fd, 0);
    if (m < 0 && m > -4096) return 140 + (int)(-m & 0x1f);
    long z = 0; long r = sc(SYS_ioctl, fd, BINDER_SET_CONTEXT_MGR_, (long)&z, 0, 0, 0);
    if (r < 0) return 150 + (int)(-r & 0x1f);
    static unsigned char rb[256]; struct bwr bw; u32 handle = 0; int got = 0;
    for (int tries = 0; tries < 24 && !got; tries++) {
        msleep(250);
        memset(&bw, 0, sizeof bw); bw.read_size = sizeof rb; bw.read_buffer = (ul)rb;
        long rr = sc(SYS_ioctl, fd, BINDER_WRITE_READ_, (long)&bw, 0, 0, 0);
        if (rr < 0 && rr != -11) return 170 + (int)(-rr & 0x1f);
        for (long i = 0; i + 4 <= bw.read_consumed; ) {
            u32 c = *(u32 *)(rb + i); i += 4;
            if (c == BR_TRANSACTION_ && i + (long)sizeof(struct btd) <= bw.read_consumed) {
                struct btd *t = (struct btd *)(rb + i); i += sizeof(struct btd);
                struct fbo *o = (struct fbo *)t->buffer;
                if (o->type == T_HANDLE) { handle = o->binder_or_handle; got = 1; }
            }
        }
    }
    if (!got) return 90;
    long nf = sc(SYS_open, (long)"/dev/gvnull", 2, 0, 0, 0, 0);
    if (nf < 0) return 160;
    struct fbo obj; memset(&obj, 0, sizeof obj); obj.type = T_FD; obj.binder_or_handle = (u32)nf;
    u32 off = 0; struct btd tr; memset(&tr, 0, sizeof tr);
    tr.target = handle; tr.flags = 1; tr.data_size = sizeof obj; tr.buffer = (ul)&obj; tr.offsets_size = sizeof off; tr.offsets = (ul)&off;
    struct { u32 cmd; struct btd tr; } wr; wr.cmd = BC_TRANSACTION_; wr.tr = tr;
    memset(&bw, 0, sizeof bw); bw.write_size = sizeof wr; bw.write_buffer = (ul)&wr; bw.read_size = sizeof rb; bw.read_buffer = (ul)rb;
    r = sc(SYS_ioctl, fd, BINDER_WRITE_READ_, (long)&bw, 0, 0, 0);
    if (r < 0) return 180 + (int)(-r & 0x1f);
    for (long i = 0; i + 4 <= bw.read_consumed; i += 4) {
        u32 c = *(u32 *)(rb + i);
        if (c == BR_TRANSACTION_COMPLETE_) return DELIVERED;
        if (c == BR_FAILED_REPLY_) return FAILED;
    }
    return 79;
}
static int fd_scenario_C(const char *dom) {
    if (setcon(dom) < 0) return 99;
    long fd = sc(SYS_open, (long)"/dev/gvbinder", 2, 0, 0, 0, 0);
    if (fd < 0) return 130 + (int)(-fd & 0x1f);
    long m = sc(SYS_mmap2, 0, 0x20000, 1, 2, fd, 0);
    if (m < 0 && m > -4096) return 140 + (int)(-m & 0x1f);
    struct fbo obj; memset(&obj, 0, sizeof obj); static u32 mark;
    obj.type = T_BINDER; obj.binder_or_handle = (u32)&mark; obj.cookie = (u32)&mark; obj.flags = 0x17f;   /* + ACCEPTS_FDS */
    u32 off = 0; struct btd tr; memset(&tr, 0, sizeof tr);
    tr.target = 0; tr.flags = 1; tr.data_size = sizeof obj; tr.buffer = (ul)&obj; tr.offsets_size = sizeof off; tr.offsets = (ul)&off;
    struct { u32 cmd; struct btd tr; } wr; wr.cmd = BC_TRANSACTION_; wr.tr = tr;
    static unsigned char rb[256]; struct bwr bw; memset(&bw, 0, sizeof bw);
    bw.write_size = sizeof wr; bw.write_buffer = (ul)&wr; bw.read_size = sizeof rb; bw.read_buffer = (ul)rb;
    long r = sc(SYS_ioctl, fd, BINDER_WRITE_READ_, (long)&bw, 0, 0, 0);
    if (r < 0) return 170 + (int)(-r & 0x1f);
    msleep(4500);                                  /* stay alive so A can send to our node */
    return 0;
}
static int wait_code(long pid) {
    int st = 0; long wr = sc(SYS_wait4, pid, (long)&st, 0, 0, 0, 0);
    if (wr != pid) return 250;
    return (st & 0x7f) ? 200 + (st & 0x7f) : (st >> 8) & 0xff;
}
static int run_fd_case(const char *dom) {
    long a = sc(SYS_fork, 0, 0, 0, 0, 0, 0);
    if (a == 0) { sc(SYS_exit, fd_scenario_A(), 0, 0, 0, 0, 0); for (;;) ; }
    msleep(700);
    long c = sc(SYS_fork, 0, 0, 0, 0, 0, 0);
    if (c == 0) { sc(SYS_exit, fd_scenario_C(dom), 0, 0, 0, 0, 0); for (;;) ; }
    int ca = wait_code(a), cc = wait_code(c);
    if (cc != 0) { out("  (service process C exit code "); outn(cc); out(")\n"); }
    return ca;
}


static char klog[262144];
static int count_in(const char *hay, long n, const char *needle) {
    int c = 0; long l = (long)slen(needle);
    for (long i = 0; i + l <= n; i++) { long k = 0; while (k < l && hay[i + k] == needle[k]) k++; if (k == l) c++; }
    return c;
}
static void klog_report(const char *tag) {
    long n = sc(SYS_syslog, 3, (long)klog, sizeof klog - 1, 0, 0, 0);   /* SYSLOG_ACTION_READ_ALL */
    out("KLOG["); out(tag); out("] ring bytes="); outn(n);
    if (n > 0) {
        out(" avc="); outn(count_in(klog, n, "avc: "));
        out(" avc-denied-enforced="); outn(count_in(klog, n, "permissive=0"));
        out(" ioctlcmd="); outn(count_in(klog, n, "ioctlcmd"));
        out(" audit_lost="); outn(count_in(klog, n, "audit_lost"));
    }
    out("\n");
}

static long audit_fd = -1;
static unsigned char nlbuf[65536];
static void audit_nl_open(void) {
    audit_fd = sc(SYS_socket, 16, 3, 9, 0, 0, 0);                      /* AF_NETLINK, SOCK_RAW, NETLINK_AUDIT */
    out("audit netlink socket: "); outn(audit_fd); out("\n");
    if (audit_fd < 0) return;
    u32 sa[3] = { 16, 0, 0 };                                           /* sockaddr_nl: family, pid (0 = kernel assigns), groups */
    long b = sc(SYS_bind, audit_fd, (long)sa, 12, 0, 0, 0); out("bind: "); outn(b); out("\n");
    struct { u32 len, type_flags, seq, pid; u32 mask, enabled, failure, apid, rate, backlog, lost, blog; } m;
    memset(&m, 0, sizeof m);
    m.len = sizeof m; m.type_flags = 1001u | (1u << 16);               /* AUDIT_SET, NLM_F_REQUEST */
    m.mask = 1 | 4; m.enabled = 1; m.apid = (u32)sc(20, 0, 0, 0, 0, 0, 0);      /* AUDIT_STATUS_ENABLED | AUDIT_STATUS_PID, pid = getpid() */
    long r = sc(SYS_sendto, audit_fd, (long)&m, sizeof m, 0, 0, 0); out("AUDIT_SET (register as audit daemon): "); outn(r); out("\n");
}
static void audit_nl_report(void) {
    if (audit_fd < 0) return;
    int total = 0, denied = 0; long n;
    while ((n = sc(SYS_recvfrom, audit_fd, (long)nlbuf, sizeof nlbuf, 0x40 /* MSG_DONTWAIT */, 0, 0)) > 0) {
        for (long off = 0; off + 16 <= n; ) {
            u32 len = *(u32 *)(nlbuf + off); u32 type = *(u32 *)(nlbuf + off + 4) & 0xffff;
            /* The kernel's audit code stores only the payload length in nlmsg_len (not header + payload). */
            if (off + 16 + (long)len > n) break;
            char *txt = (char *)(nlbuf + off + 16); long tl = (long)len;
            if (type == 1400) {
                total++;
                if (count_in(txt, tl, "permissive=0")) { denied++; out("NETLINK-AUDIT: "); { long w = sc(SYS_write, 1, (long)txt, tl, 0, 0, 0); (void)w; out("\n"); } }
            }
            off += 16 + ((len + 3) & ~3u);
        }
    }
    out("NETLINK-AUDIT summary: avc records received="); outn(total); out(" enforced denials="); outn(denied); out("\n");
}

/* binder_thread use-after-free probe (see header). The binder poll hook only watches thread->wait while the thread has a
 * transaction in flight and no other pending work, so a context manager is started first and the probe thread sends it a
 * synchronous transaction without reading the reply. No SELinux involved (no policy is loaded in this mode). */
static long start_ctxmgr_plain(void) {
    long pid = sc(SYS_fork, 0, 0, 0, 0, 0, 0);
    if (pid == 0) {
        int code = 0;
        long fd = sc(SYS_open, (long)"/dev/binder", 2, 0, 0, 0, 0);
        if (fd < 0) code = 130 + (int)(-fd & 0x1f);
        else {
            long m = sc(SYS_mmap2, 0, 0x20000, 1, 2, fd, 0);
            if (m < 0 && m > -4096) code = 140 + (int)(-m & 0x1f);
            else { long z = 0; long r = sc(SYS_ioctl, fd, BINDER_SET_CONTEXT_MGR_, (long)&z, 0, 0, 0); if (r < 0) code = 150 + (int)(-r & 0x1f); }
            if (code == 0) msleep(8000);
        }
        sc(SYS_exit, code, 0, 0, 0, 0, 0); for (;;) ;
    }
    return pid;
}
static int epoll_probe(void) {
    long fd = sc(SYS_open, (long)"/dev/binder", 04002 /* O_RDWR|O_NONBLOCK */, 0, 0, 0, 0);
    if (fd < 0) return 130 + (int)(-fd & 0x1f);
    u32 payload[2] = { 1, 2 };
    struct btd tr; memset(&tr, 0, sizeof tr); tr.target = 0; tr.flags = 0;   /* synchronous: transaction_stack stays set */
    tr.data_size = sizeof payload; tr.buffer = (ul)payload;
    struct { u32 cmd; struct btd tr; } wr; wr.cmd = BC_TRANSACTION_; wr.tr = tr;
    static unsigned char rb2[128]; struct bwr bw; memset(&bw, 0, sizeof bw); bw.write_size = sizeof wr; bw.write_buffer = (ul)&wr;
    bw.read_size = sizeof rb2; bw.read_buffer = (ul)rb2;     /* consume BR_TRANSACTION_COMPLETE, leave the reply pending */
    long r = sc(SYS_ioctl, fd, BINDER_WRITE_READ_, (long)&bw, 0, 0, 0);
    out("sync transaction written: "); outn(r); out("\n");
    long ep = sc(SYS_epoll_create, 1, 0, 0, 0, 0, 0);
    if (ep < 0) return 140;
    u32 ev[3] = { 1 /* EPOLLIN */, 0, 0 };
    r = sc(SYS_epoll_ctl, ep, 1 /* EPOLL_CTL_ADD */, fd, (long)ev, 0, 0);
    out("epoll_ctl ADD binder fd: "); outn(r); out("\n");
    u32 z = 0; r = sc(SYS_ioctl, fd, 0x40046208u /* BINDER_THREAD_EXIT */, (long)&z, 0, 0, 0);
    out("BINDER_THREAD_EXIT: "); outn(r); out("\n");
    sc(SYS_close, ep, 0, 0, 0, 0, 0);                                      /* epoll tears down its watch of the (freed?) wait list */
    for (int i = 0; i < 64; i++) {                                          /* reuse freed thread objects: the poison check happens here */
        long f2 = sc(SYS_open, (long)"/dev/binder", 2, 0, 0, 0, 0);
        if (f2 >= 0) { u32 v[1] = { 0 }; sc(SYS_ioctl, f2, 0xC0046209u /* BINDER_VERSION */, (long)v, 0, 0, 0); }
    }
    return 0;
}

static void cmdline_flag(const char *cl, const char *flag, int *dst) { if (has(cl, flag)) *dst = 1; }

void init_main(void) {
    char cl[512]; int load_only = 0, hooks = 0, enf_load = 0;
    sc(SYS_mkdir, (long)"/proc", 0755, 0, 0, 0, 0); sc(SYS_mkdir, (long)"/sys", 0755, 0, 0, 0, 0); sc(SYS_mkdir, (long)"/dev", 0755, 0, 0, 0, 0);
    sc(SYS_mount, (long)"proc", (long)"/proc", (long)"proc", 0, 0, 0);
    sc(SYS_mount, (long)"sysfs", (long)"/sys", (long)"sysfs", 0, 0, 0);
    sc(SYS_mount, (long)"devtmpfs", (long)"/dev", (long)"devtmpfs", 0, 0, 0);
    out("\n=== GV-SELINUX-TEST start ===\n");
    show("kernel", "/proc/version");
    if (readfile("/proc/cmdline", cl, sizeof cl) < 0) cl[0] = 0;
    cmdline_flag(cl, "gvmode=load", &load_only); cmdline_flag(cl, "gvexp=hooks", &hooks); cmdline_flag(cl, "gvenforce=1", &enf_load);
    if (has(cl, "gvmode=epoll")) {
        start_ctxmgr_plain(); msleep(700);
        long pid = sc(SYS_fork, 0, 0, 0, 0, 0, 0);
        if (pid == 0) { sc(SYS_exit, epoll_probe(), 0, 0, 0, 0, 0); for (;;) ; }
        int st = 0; long wr = sc(SYS_wait4, pid, (long)&st, 0, 0, 0, 0);
        out("probe child: wait4="); outn(wr); out(" status="); outn(st); out("\n");
        msleep(500);
        klog_report("after-probe");
        goto done;
    }
    long mr = sc(SYS_mount, (long)"selinuxfs", (long)"/sys/fs/selinux", (long)"selinuxfs", 0, 0, 0);
    out("mount selinuxfs: "); outn(mr); out("\n");
    if (mr < 0) { out("RESULT selinuxfs-unavailable\n"); goto done; }
    show("policyvers (kernel maximum, before load)", "/sys/fs/selinux/policyvers");
    writefile("/sys/fs/selinux/enforce", ((load_only && !enf_load) || has(cl, "gvenforce=0")) ? "0" : "1");
    show("printk_ratelimit (seconds, 0 = unlimited)", "/proc/sys/kernel/printk_ratelimit");
    show("printk_ratelimit_burst", "/proc/sys/kernel/printk_ratelimit_burst");
    if (has(cl, "gvratelimit=off")) {
        out("setting kernel.printk_ratelimit=0: "); outn(writefile("/proc/sys/kernel/printk_ratelimit", "0")); out("\n");
        show("printk_ratelimit now", "/proc/sys/kernel/printk_ratelimit");
    }
    if (has(cl, "gvaudit=netlink")) audit_nl_open();
    long n = readfile("/sepolicy", pol, sizeof pol);
    out("policy file bytes: "); outn(n); out("\n");
    long fd = sc(SYS_open, (long)"/sys/fs/selinux/load", 1, 0, 0, 0, 0);
    long w = sc(SYS_write, fd, (long)pol, n, 0, 0, 0);
    out("load_policy write returned: "); outn(w); out(w == n ? "  (LOADED)\n" : "  (FAILED)\n");
    show("enforce (after load)", "/sys/fs/selinux/enforce");
    show("policyvers (after load)", "/sys/fs/selinux/policyvers");
    if (w != n) { out("RESULT policy-load-failed\n"); goto done; }
    out("RESULT policy-loaded\n");
    if (load_only) goto done;
    if (has(cl, "gvmode=execmod")) {
        sc(SYS_mkdir, (long)"/tmp", 01777, 0, 0, 0, 0);
        out("mount tmpfs /tmp: "); outn(sc(SYS_mount, (long)"tmpfs", (long)"/tmp", (long)"tmpfs", 0, 0, 0)); out("\n");
        {
            static char page[4096]; memset(page, 0x90, sizeof page);
            static const struct { const char *path; const char *ctx; } pf[] = {
                { "/tmp/gvlib-libgal", "u:object_r:libgal_file:s0" }, { "/tmp/gvlib-other", "u:object_r:gv_em_file:s0" } };
            for (int k = 0; k < 2; k++) {
                writefile("/proc/self/attr/fscreate", pf[k].ctx);
                long f = sc(SYS_open, (long)pf[k].path, 0102, 0644, 0, 0, 0);
                writefile("/proc/self/attr/fscreate", "");
                long w = f < 0 ? f : sc(SYS_write, f, (long)page, sizeof page, 0, 0, 0);
                out("prepared "); out(pf[k].path); out(" label "); out(pf[k].ctx); out(": "); outn(w); out("\n");
                if (f >= 0) sc(SYS_close, f, 0, 0, 0, 0, 0);
            }
        }
        int total = (int)(sizeof extests / sizeof extests[0]), pass = 0;
        for (int i = 0; i < total; i++) {
            long got = run_child(&extests[i]); int exp = extests[i].exp_hooks;
            out(got == exp ? "[PASS] " : "[FAIL] "); out(extests[i].name); out("  got="); outn(got); out(" expected="); outn(exp); out("\n");
            if (got == exp) pass++;
        }
        out("SUMMARY pass="); outn(pass); out(" total="); outn(total); out("\n");
        goto done;
    }
    {
        int bm = parse_misc_minor("binder");
        out("binder misc minor: "); outn(bm); out("\n");
        if (bm >= 0) make_node("/dev/gvbinder", 10, bm, "u:object_r:binder_device:s0");
        make_node("/dev/gvnull", 1, 3, "u:object_r:null_device:s0");
    }
    {
        int total = (int)(sizeof tests / sizeof tests[0]), pass = 0, i, ctx_started = 0;
        long cm = -1;
        for (i = 0; i < total; i++) {
            const struct test *t = &tests[i];
            if (t->kind >= K_TX_PLAIN && !ctx_started) { msleep(1500); cm = start_ctxmgr(); msleep(700); ctx_started = 1; }
            long got = run_child(t); int exp = hooks ? t->exp_hooks : t->exp_nohooks;
            out(got == exp ? "[PASS] " : "[FAIL] "); out(t->name); out("  got="); outn(got); out(" expected="); outn(exp); out("\n");
            if (got == exp) pass++;
            msleep(300);
        }
        if (ctx_started) { int st = 0; sc(SYS_wait4, cm, (long)&st, 0, 0, 0, 0); out("context-manager helper exit code: "); outn((st & 0x7f) ? 200 + (st & 0x7f) : (st >> 8) & 0xff); out("\n"); }
        {   /* hook 4 cases (kept out of the table because they need two cooperating processes) */
            static const struct { const char *name; const char *dom; int exp_hooks; int exp_nohooks; } fc[] = {
                { "binder transfer-file gv_svc_no  (receiver lacks fd:use)", "u:r:gv_svc_no:s0", FAILED, DELIVERED },
                { "binder transfer-file gv_svc_ok  (receiver may fd:use)",   "u:r:gv_svc_ok:s0", DELIVERED, DELIVERED },
            };
            for (int k = 0; k < 2; k++) {
                msleep(1500);
                long got = run_fd_case(fc[k].dom); int exp = hooks ? fc[k].exp_hooks : fc[k].exp_nohooks;
                out(got == exp ? "[PASS] " : "[FAIL] "); out(fc[k].name); out("  got="); outn(got); out(" expected="); outn(exp); out("\n");
                total++; if (got == exp) pass++;
            }
        }
        out("SUMMARY pass="); outn(pass); out(" total="); outn(total); out("\n");
    }
done:
    audit_nl_report();
    if (has(cl, "gvklog=1")) klog_report("end");
    out("=== GV-SELINUX-TEST end ===\n");
    sc(SYS_reboot, 0xfee1dead, 672274793, 0x01234567, 0, 0, 0);       /* RESTART; QEMU runs with -no-reboot */
    for (;;) ;
}

__attribute__((naked)) void _start(void) { __asm__ volatile("bl init_main"); }
