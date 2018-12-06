# control group

`include/linux/cgroup.h` : cgroup interface.

``` c
struct cgroup_root;
struct cgroup_subsys;
struct cgroup;
extern int cgroup_init_early(void);
extern int cgroup_init(void);
extern void cgroup_fork(struct task_struct *p);
extern void cgroup_post_fork(struct task_struct *p);
extern void cgroup_exit(struct task_struct *p);
extern int cgroupstats_build(struct cgroupstats *stats, struct dentry *dentry);
extern int proc_cgropu_show(struct seq_file *m, struct pid_namespace *ns, pid, tsk);

#define SUBSYS(_x) _x ## _cgrp_id,
enum cgroup_subsys_id {
    #include <linux/cgroup_subsys.h>
    CGROUP_SUBSYS_COUNT,
};
#undef SUBSYS
```

看一下有哪些 subsys.

`include/linux/cgroup_subsys.h`, 都是用宏包着的.

``` c
#if IS_ENABLED(CONFIG_CPUSETS)
SUBSYS(cpuset)
#endif
```

- cpuset
- pids
- cpu
- cpuacct
- schedtune
- blkio
- memory
- devices
- freezer
- net_cls
- perf_event
- hugetlb
- iolimit
- debug
- workingset

cgroup 有 sysfs 的接口在 /sys/fs/cgroup

最后居然还这句话:
`DO NOT ADD ANY SUBSYSTEM WITHOUT EXPLICIT ACKS FROM CGROUP MAINTAINERS` wwwww

回到 `cgroup.h`

``` c
// per subsystem/per cgroup state maintained by the system. This is
// the fundamental structural building block that controllers deal with.
// Fields marked with "PI:" are public and immutable and may be accessed
// directly without synchronization.
struct cgroup_subsys_state {
    // PI: the cgroup that this css is attached to..
    struct cgroup *cgroup;
    // PI: the cgroup subsystem that this css is attached to
    struct cgroup_subsys *ss;
    // ref count - access via css_[try]get() and css_put()
    struct percpu_ref refcnt;
    // PI: the parent css // 居然还有结构的..
    struct cgroup_subsys_state *parent;
    // sibling list anchored at the parent's ->children
    struct list_head sibling;
    struct list_head children;
    // PI : subsys-unique ID, o is unused , root is 1, The matching css can be
    // looked up using css_from_id().
    int id;
    unsigned int flags;
    // monotonically increasing unique serial number which defined a uniform
    // order among all csses. It's guaranteed that all ->children lists are in
    // the ascending order of ->serial_nr and used to allow interrupting and
    // resuming iterations.
    u64 serial_nr;
    // percpu_ref killing and rcu release
    struct rcu_head rcu_head;
    struct work_struct destroy_work;
};
```

``` c
// used in css.flags
enum {
    CSS_NO_REF = (1<<0),// no reference counting for this css
    CSS_ONLINE = (1<<1), // between ->css_online() and ->css_offline()
    CSS_RELEASE = (1<<2), // refcnt reached zero, released.
}
void css_get(css);
bool css_tryget(css);
bool css_tryget_online(css); // try get if online
void css_put(css);
```

``` c
// bits in  cgroup->flags field
enum {
    CGRP_NOTIFY_NO_RELEASE,
    CGRP_CPUSEt-CLONE_CHILDREN,
};
// the cgroup
struct cgroup {
    // self css with NULL ->ss, points back to this cgroup
    struct cgroup_subsys_state self;
    unsigned long flags;
    // idr allocated in-hierarchy ID
    // 0 not used, root is 1, a new cgroup will be assigned with a smallest id
    // alloc/remove protected by cgroup_mutex.
    int id;
    // if the cgroup contains any tasks, it contributes one to this.
    int poplulated_cnt
    struct kernfs_node *kn;     // kernfs netr
    struct kernfs_node *populated_kn;
    // the bitmask of subsystems enabled on the child cgroups.
    // ->subtree_control is the one configured through "cgroup.subtree_control"
    // while ->child_subsys_mask is the effective one which may have more
    // subsystems enabled. Controller knobs are made available iff it's enabled
    // in ->subtree_control.
    unsigned int subtree_control;
    unsigned int child_subsys_mask;
    // private pointers for each registered subsystem.
    struct cgroup_subsys_state __rcu *subsys[]
    struct cgroup_root *root;
    // list of cgrp_cset_links pointing at css_sets with tasks in this cgroup.
    // protected by css_set_lock;
    struct list_head cset_links;
    // on the default hierarchy, a css_set for a cgroup with some subsys disabled
    // will point to css's which are associated with the closest ancestor which has
    // the subsys enabled. The following lists all css_sets which point ot htis cgroup's css
    // for the given subsystem.
    struct list_head e_csets[CGROUP_SUBSYS_COUNT];

    struct list_head pidlists;
    struct mutex pidlist_mutex;

    wait_queue_head_t offline_waitq;
    struct work_struct release_agent_work;
};
```

cgroup root ..

``` c
// cgroup_root->flags
enum {
    CGRP_ROOT_SANE_BEHAVIOR = (1 << 0),// __DEVEL__sane_behavior specified
    CGRP_ROOT_NOPREFIX  = (1 << 1), // mounted subsystems have no named prefix
    CGRP_ROOT_XARRT = (1 << 2), //
    CGRP_ROOT_CPUSET_NOPREFIX = (1 << 3),// only cpuset have no named prefix
}
// a cgroup_root represents the root of a cgroup hierarchy, and may be associated
// with a kernfs_root to form an active hierarchy. This is internal to cgroup core.
// Don't access directly from controllers.
struct cgroup_root {
    struct kernfs_root *kf_root;
    unsigned int subsys_mask;
    int hierarchy_id; // unique id for this hierarchy. 看来有好多个
    struct cgroup cgrp; // the root cgroup,
    atomic_t nr_cgrps;
    struct list_head root_list; ;; a list running through the active hierarchies.
    unsigned int flags;
    struct idr cgroup_idr;
    char release_agent_path[PATH_MAX];
    char name[MAX_CGRUP_ROOT_NAMELEN];
};
```

``` c
// a css_set is a struct holding pointers to a set of cgroup_sbusys_sate objects.
// this saves space in the task struct object and speeds up fork()/exit(),
// since a single inc/dec and list_add/del() can bump the reference count on
// the entire cgroup set for a task.
struct css_set {
    stomic_t refcount;
    struct hlist_node hlist;
    struct list_head tasks;
    struct list_head mg_tasks;
    struct list_head cgrp_listk;
    struct cgroup *dfl_cgrp;
    struct cgroup_subsys_state *subsys[CGROPU_SUBSYS_COUNT];
    struct list_head mg_preload_node;
    // list of csets participating in the on-going migrations..
    struct list_head mg_node;
    struct cgroup *mg_src_cgrp;
    struct css_set *mg_dst_cst;
    struct list_head e_cset_node[CGROUP_SBUSYS_COUNT];
    struct rcu_head rcu_head;
};
```

cftype. Handler definitions for cgroup control files

``` c
struct cftype {
    // by convention, the name should begin with the name of the subsystem.
    // followed by a period.
    char name[MAX_CFTYPE_NAME];
    int private;
    umode_t mode;
    size_t max_write_len;
    unsigned int flags;
    struct cgroup_subsys *ss;
    struct list_head node;
    struct kernfs_ops *kf_ops;
    u64 (*read_u64)(css, struct cftype *cft);
    s64 (*read_s65)(css, cft);
    int (*seq_show)(struct seq_file *sf, void *v);
    void *(*seq_start)(sf, ppos);
    void *(*seq_next)(sf, v, ppos);
    void (*seq_stop)(sf, v);
    int (*write_u64)(css, cft, val);
    int (*write_s64)(css, cft, val);
    ssize_t (*write)(of, buf, nbytes, off);
};
```

后面还有一半, 先看看 document.

`Cocumentation/cgropus/*`

Cpusets provide a mechanism for assigning a set of CPUs and memory nodes to a
set of tasks.  这个很像 cgroups. 估计 cgroups 是从 这个发展出来的.
为了 NUMA. 之前就有 sched_setaffinity, mbind, set_mempolicy, 这些控制
任务使用的 cpu 和内存的, cpusets 扩展之.

- cpusets are sets of allowed cpus and memory nodes
- each task in the system is attached to a cpuset, via a pointer in the task
  structure to a reference counted cgroup structure...
- calls to sched_setaffinity are filtered to just those CPUS allowed in that
  task's cpuset.
- calls to mbind and set_mempolicy are filtered to just those memory nodes
  allowed in that task's cpuset.
- the root cpuset contains all the systems CPUs and memory nodes.
- for any cpuset, on e can define child cpusets containing a subset of the
  parents CPU and Memory Node resources.
- The hierarchy of cpusets can be mounted at /dev/cpuset, for browsing and
  manipulation for user space.
- A cpuset may be marked exclusive, which ensures that no other cpuset (except
  direct ancestors and descendants) may contain any overlapping CPUs and Memory
  Nodes.
- You can list all the tasks (by pid) attached to any cpuset.

The implementation of cpusets.:

- init/main.c, to initialized the root cpuset at system boot.
- in fork and exit, to attach and detach a task from its cpuset.
- in sched_setaffinity, to mask the requested CPUs by what's allowed in cpuset.
- in sched.c , migrating tasks within CPUS allowed by cpuset, if possible
- in the mbind and set_mempolicy system calls, to mask the requested memory
  nodes by that's allowed in that task's cpuset.
- in page_alloc.c, to restrict
- in vmscan.c, to restrict **page recovery** to the current cpuset.

mount "cgroup" filsystem type in order to enable browsing and modifying the
cpusets presently known to the kernel. no new system calls are added for
cpusets.  原来如此, 加新功能一半都是用虚拟文件.. 不过这些接口也不一定稳定吧.

The /proc/pid/status file for each task has for added lines, cpu_allowed,
allowed_list, mem_allowed, mems_allowed_list.

Each cpuset is represented by a directory in the cgroup file system
containing (on top of the standard cgroup files) the following files describing
that cpuset:

- cpusets.cpus: list of CPUS in that cpuset
- cpuset.mems: list of Memory Nodes in that cpuset
- cpusets.memory_migrate flag:
- etc.

例子, 怎么使用 cpuset.

后面还有些， 不过 cpuset 这个还是很好理解的。

在回头看看 cgroups 的文档， `Documentation/cgroups/cgroups.txt`.

Control Groups provide a mechanism for aggregating/partitioning sets of tasks,
and all their future children, into hierarchical groups with specialized
behavior.

a *cgroup* associates a set of tasks with a set of parameters for one or more
subsystems.

a *subsystem* is a module that makes use of the task grouping facilities
provides by cgroups to treat groups of taks in particular ways. A subsystem is
typically a "resource controller" that schedules a rescource or applies
per-cgroup limits, but it may be anything that wants to act on a group of
processes.

a *hierarchy* is a set of cgroups arranged in a tree, such that every task in
the system is in exactly one of the cgroups in the hierarcchy, and a set of
subsystems; each subsystem has system-specific state attached to each cgroup in
the hierarchy. Each hiearachy has an instance of the cgroup virtual fiflesystem
associated with it.

At any one time there may be multiple active hierarchies of task crgoups. Each
hierarchy is a partition of all tasks in the system.

user-level code may create and destroy cgroups by name in an instance of the
cgroup virtual file system, specify and query to which cgroup a task is
assigned, and list the task PIDs assigned to a cgroup. Those creations and
assignments only affect the hierarchy associated with that instance of the
cgroup file system. e.g. cpusets.

On their own, the only use for cgroups is for simple job tracking. The intention
is that other subsystems hook into the generic cgroup support to provide new
attributes for cgroups, such as accounting/limiting the resources which
processes in a cgroup can access.

- a cgroup associates a set of tasks with a set of parameters for one or more
  subsystems.
- 这些子系统主要利用 cgroups 将 task 分为层级式结构.

cgroup的实现:

- each task in the system has a refrence-counted pointer to a css_set.
- a css_set contains a set of reference-counted pointers to
  css(cgroup_subsys_state) objest. one fore each cgroup subsystem registered in
  the system. (for perfromance)
- a cgroup hierachy filesystem can be mounted for browsing and manipulation fro
  user space
- you can list all the tasks (by PID) attached to any cgroup.
- hook: init/main.c to initilaze the root cgrous and inital css_set.
- hook: fork and exit. to attach and detach a task from its css_set.

每 个task 的 /proc/pid/cgroup 里面有它所属的 cgroup.
每个cgroup 通过 cgroup file system 里面的directory来表示. 里面有如下文件:

- tasks: list of tasks attached to that cgroup. Writing a thread ID into this
  file moves the thread into this cgroup
- cgroup.procs: list of thread group IDs in the cgroup. Writing as above
- notify_on_realease flag: run the release agent on exit?
- release_agent: the path to use fore release notification.

还可能有其他的文件, subsystem 自己加的.

通过 mkdir 来创建新的 cgroups, 移动 tasks 的权限就是 dirctory 的权限(nice!)

实现有限复杂的细节先跳过.

例子:

1. mount -t tmpfs cgroup_root /sys/fs/cgroup
2. mkdir /sys/fs/cgroup/cpuset
3. mount -t cgroup -ocpuset cpuset /sys/fs/cgroup/cpuset
4. Create the new cgroup by doing mkdir's and write's in the /sys/fs/cgroup
   virtual file system.
5. Start a task that will be the dounding father of the new job.
6. Attach that task to the new cgroup by writing its PID to the
   /sys/fs/cgroup/cpuset/tasks file for that cgroup
7. fork exec and clone the job tasks from this founding father task.

## blkio

创建一个 subsystem. 需要

- add an entry in linux/cgroup_subsys.h
- define a cgroup_subsys object caleed (name)_subsys

blkio.

``` text
BLK_DEV_THROTTLING: 2010 Vivek Goyal, Redhat
block layer bio throttling support,
depends on  BLK_CGROUP=y

Block layer bio throttling uspport. It can be used to limit the IO rate to a
device. IO rate policies are per cgroup and one needs to mount and use blkio
cgroup controller for creating cgroups and specifying per device IO rate policies.
see documentation/cgroups/blkio-controller.txt
```

blk_dev_throttling 依赖于 blockio_cgroup.

`block/blk-cgroup.h`

``` c

```

## iolimit kernel support

`blkcg->type` 是怎么来的. 20171102.

`CONFIG_CGROUP_IOLIMIT=y`, 增加文件 `cgroup_io_limit.c` `iolimit_cgroup.h`.
Provides a cgroup implementing for io bandwidth while a process in the cgroup
read or write. 这是添加了个新的 subsystem 啊..

`blk-cgroup.h`

``` c
enum blk_throtl_type {
    BLK_THROTL_TA,  // top app
    BLK_THROTL_FG,  // foreground
    BLK_THROTL_KBG,  // key background
    BLK_THROTL_SBG,  // system background
    BLK_THROTL_BG,
    BLK_THROTL_TYPE_NR,
}
```

``` c
struct blkcg {
    // ...
    unsigned int type;
}
```

原本这个 `type` 是 `fg_flag`, 应该只能表示进程是否为 foreground, 后来细化了.

`blk-throttle.c` : Interface for controlling IO bandwidth on a request queue.

``` c
static int tg_set_cgroup_type(struct cgroup_subsys_state *css,
                struct cftype *cft, u64 val) {
    struct blkcg * blkcg = css_to_blkcg(css);
    unsigned int type = (unsigned int)val;
    blkcg->type = type;
}
```

这看到这里对 `blkcg->type` 赋值, 所以. 这个 type 只有是 android framework
写的了.

``` c
static struct cftype throtl_files[] = {
    .write = tg_set_iops_slice_devce,
    {
        .name = "throttle.type",
        .seq_show = tg_print_cgroup_type,
        .write_u64 = tg_set_cgroup_type,
    }
}
```

猜测的话, 可能是
[RunningAppProcessInfo](https://developer.android.com/reference/android/app/ActivityManager.RunningAppProcessInfo)

这是个枚举值, 可以取值:

- foreground
- visible. visible but not immediate foreground
- service
- perceptible.
- top sleep. is running the foreground UI, but the devie is asleep so not
  visible.
- can't save state, runing an app that can not save its state, thus can't be
  killed while in the background
- cached
- gone. This process does not exist.

[Processs and App lifcycle](https://developer.android.com/guide/components/activities/process-lifecycle)
介绍了四种. Android 把进程按重要等级分为4种:

1. foreground process. A process is considered to be foreground if
    - runinng an Activity at the top of the screen that the user is interacting
      with (its onResume() has been called).
    - It has a BroadcastReceiver that is currently runing,(onReceiver() running)
    - It has a Service that is currently executing code in one of its callbacks.
2. visible process. doing work that the user is currently aware of. A process is
   considered visible if:
   - It is rning an Activity that is visible to the user on-screen but not in
     the foreground(onPause() has been called). 比如弹窗, 窗户下面的那个没有
     focus的.
   - It has a Service that is running as a foreground service.
   - It is hosting a service that the system is using for a particular feature
     that the user is aware.
3. service proces.
   - holding a Service that has been started with startService(). 比如后台网络上
     传下载.
4. cached process. 不用的. 不可见的. 放在一个伪LRU list 中.

两处process 状态分类也没有完全相对应.