#define _GNU_SOURCE

#include <dlfcn.h>
#include <errno.h>
#include <limits.h>
#include <pthread.h>
#include <sched.h>
#include <stddef.h>
#include <sys/types.h>

static cpu_set_t safe_affinity;
static int safe_affinity_available;

__attribute__((constructor)) static void capture_safe_affinity(void)
{
    CPU_ZERO(&safe_affinity);
    if (sched_getaffinity(0, sizeof(safe_affinity), &safe_affinity) == 0) {
        safe_affinity_available = 1;
    }
}

static int intersect_affinity(
    size_t requested_size,
    const cpu_set_t *requested,
    cpu_set_t *filtered)
{
    size_t cpu;
    size_t cpu_limit = requested_size * CHAR_BIT;

    CPU_ZERO(filtered);
    if (!safe_affinity_available || requested == NULL) {
        return 0;
    }

    if (cpu_limit > CPU_SETSIZE) {
        cpu_limit = CPU_SETSIZE;
    }
    for (cpu = 0; cpu < cpu_limit; ++cpu) {
        if (CPU_ISSET(cpu, &safe_affinity) &&
            CPU_ISSET_S(cpu, requested_size, requested)) {
            CPU_SET(cpu, filtered);
        }
    }
    return CPU_COUNT(filtered) > 0;
}

int pthread_setaffinity_np(
    pthread_t thread,
    size_t requested_size,
    const cpu_set_t *requested)
{
    typedef int (*real_function)(pthread_t, size_t, const cpu_set_t *);
    real_function real_setaffinity;
    cpu_set_t filtered;

    real_setaffinity = (real_function)dlsym(RTLD_NEXT, "pthread_setaffinity_np");
    if (real_setaffinity == NULL) {
        return ENOSYS;
    }
    if (!intersect_affinity(requested_size, requested, &filtered)) {
        return 0;
    }
    return real_setaffinity(thread, sizeof(filtered), &filtered);
}

int sched_setaffinity(
    pid_t pid,
    size_t requested_size,
    const cpu_set_t *requested)
{
    typedef int (*real_function)(pid_t, size_t, const cpu_set_t *);
    real_function real_setaffinity;
    cpu_set_t filtered;

    real_setaffinity = (real_function)dlsym(RTLD_NEXT, "sched_setaffinity");
    if (real_setaffinity == NULL) {
        errno = ENOSYS;
        return -1;
    }
    if (!intersect_affinity(requested_size, requested, &filtered)) {
        return 0;
    }
    return real_setaffinity(pid, sizeof(filtered), &filtered);
}
