# kernel module

kernel module 是个很方便的东西, 能够调用内核的函数, 
用来做测试也不错. 


执行上下文? 在哪个线程执行?
看一下就知道了..
how to get pid of a task. 我绝对在哪本书里看到过. 不写代码立马就忘了.
记得因为 namespace 的原因, pid 也有重复的, 成立一个层级式结构.

`sched.h`
``` c
static inline pid_t task_pid_nr(tsk) { return tsk->pid; }
```

测试表明, 线程的父进程是 shell, module 运行在一个新的线程. 并且并不是内核进程.




