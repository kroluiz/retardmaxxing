#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/syscall.h>
#include <unistd.h>
#include <linux/bpf.h>
#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/fail.h>

static char log_buf[65536];
static char err_buf[sizeof(log_buf) + 256];

value ozy_prog_load(value v_insns)
{
    CAMLparam1(v_insns);
    union bpf_attr attr;
    memset(&attr, 0, sizeof(attr));
    attr.prog_type = BPF_PROG_TYPE_SOCKET_FILTER;
    attr.insns = (uint64_t)(uintptr_t)Bytes_val(v_insns);
    attr.insn_cnt = caml_string_length(v_insns) / 8;
    attr.license = (uint64_t)(uintptr_t)"GPL";
    attr.log_buf = (uint64_t)(uintptr_t)log_buf;
    attr.log_size = sizeof(log_buf);
    attr.log_level = 1;
    log_buf[0] = '\0';

    int fd = syscall(__NR_bpf, BPF_PROG_LOAD, &attr, sizeof(attr));
    if (fd < 0) {
        snprintf(err_buf, sizeof(err_buf), "BPF_PROG_LOAD: %s\n%s", strerror(errno), log_buf);
        caml_failwith(err_buf);
    }
    CAMLreturn(Val_int(fd));
}

value ozy_prog_test_run(value v_fd)
{
    static unsigned char data[64];
    union bpf_attr attr;
    memset(&attr, 0, sizeof(attr));
    attr.test.prog_fd = Int_val(v_fd);
    attr.test.data_in = (uint64_t)(uintptr_t)data;
    attr.test.data_size_in = sizeof(data);
    attr.test.repeat = 1;

    if (syscall(__NR_bpf, BPF_PROG_TEST_RUN, &attr, sizeof(attr)) < 0) {
        snprintf(err_buf, sizeof(err_buf), "BPF_PROG_TEST_RUN: %s", strerror(errno));
        caml_failwith(err_buf);
    }
    return Val_long(attr.test.retval);
}

value ozy_close(value v_fd)
{
    close(Int_val(v_fd));
    return Val_unit;
}
