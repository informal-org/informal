# 06. "Pauseless" Garbage Collection in Informal
Informal has a pluggable memory management system. You can enable the manual memory allocator, or use the default GC.
GC in Informal runs in a separate module, independent from the scheduler and the core application.
It's a completely user-mode process without any additional privilege.
GC is cooperative and carries out most of its duties without pauses.
It additionally has to work around WASM's security constraints, which prevents directly accessing the stack frame. We can’t rely on viewing or modifying any pointers that may exist in the process’s running stack.

So we can't pause your processes or even see what's going on in a process stack, so how on earth do we safely manage memory?

This would normally be impossible, but the immutability guarantees of the language open up a GC scheme that can operate independently under these constraints.

## Optimization Heuristics
Generational hypothesis - Most objects are temporary and tend to die young. Minimize fragmentation and bookkeeping for temporary objects.
Locality hypothesis - Objects that are allocated nearby in time should be allocated nearby in space. They’re likely related.
Linearity hypothesis - In an immutable language, objects can only reference past objects. Never future objects. All pointers point in the same direction. 
Class hypothesis - Objects within a class can only point to other objects specified in their class header. Use this to reduce the search space when tracing.
Data hypothesis - Separate data from pointers, to minimize the search space for tracing.
Reference hypothesis- Most objects have just a few references pointing to them.
Compactness - Cache is king. Ensure objects remain compact in memory with minimal fragmentation. The key challenge here is to ensure objects remain accessible after moving them for compaction, without rewriting pointers that may exist out of our reach on process stacks.

## Memory allocation.
There’s a simple linear block allocator, which allocates region blocks. Regions have a minimum size of 1 WASM page - 64 KB. 
Each region is class-specific - this allows us to skip storing per-object headers altogether. All GC and class metadata is stored in the region header and written solely by the GC.
Each class region forms a linked list structure to grow, with the class pointing to the latest region, and each region pointing to the previous region for that class.
Objects are always allocated linearly in the latest slot. They’re never used to “fill in” spaces that have been freed. All objects are thus stored in a sorted order by their Object ID. 

## Process Garbage Collection
Processes in Informal are meant to be lightweight and ephemeral. 
Each process’s memory is completely private - all references to it will be completely local.
When a process terminates, all of its local heap memory can thus be freed. The data portion of the heap is freed immediately without any additional scanning. 
Pointers are managed separately. Each pointer has a 1 bit reference counter which indicates whether it’s the sole, exclusive reference to an object on the heap. This bit is reset before the pointer is ever shared externally with other processes. If this is the sole reference to that object on the shared heap, we mark the underlying object as garbage (but trace and sweep it on the next minor collection to avoid tiny collections). Since a large share of objects are temporary with single owners, this allows us to free them eagerly without the typical overhead of reference counting.

## Heap Garbage Collection
Since all objects are allocated per-class, and since the schema for classes are known at compile time, the search space for each mark and sweep can be reduced to - the classes that reference this object and currently running processes. The linearity property can also be used to reduce the searchspace of potential references.
We don’t have direct visibility into what a process is doing, and what pointers may exist in its memory. So instead, we rely on the compiler to make this data visible for us by adding bookkeeping code. Complete visibility into all objects referenced by a process will be inefficient and transient - imagine all of the pointers it goes through in a single hot loop iterating over an array. Instead, the only things a process can access are
References passed to it as parameters. 
Other references accessible from those references.
New objects it allocated itself. 
And any other objects statically known at compile time.

Given this, the only metadata that a stack needs to emit are its reference parameters and new allocations it makes. This metadata is also used to implement coroutines. 

## Compaction
Having objects laid out compactly in memory improves how much useful data is loaded into cache. As objects are garbage collected, memory gets fragmented - with live objects intermixed with dead objects. Typically, this garbage space is re-used to allocate new objects, at the cost of losing linearity and locality. Additionally, if we move any objects to compact the space, any direct pointers to that object would need to be rewritten - which requires suspending processes and accessing their stack (two things we cannot do).
Instead, our compaction scheme relies on the fact that there are no direct pointers in Informal. All pointers reference the region ID and the object ID within that region. This can be used to efficiently find each object, even after it’s been moved. We can thus compact as needed, without requiring major GC pauses or rewriting objects that a process owns. 
Objects are always compacted within a region, and occasionally compacted with the past region if there’s sufficient free space.
Since processes may continue to access a region while it’s being compacted, compassion is done through copying into a separate region. Once the compaction is done, we leave metadata in the region header referencing the new location, and rewrite pointers on the heap. Processes are responsible for rewriting their own pointers on the next access (avoids shared memory or locking). A separate Region GC pass runs over the process heap space to recognize when the fragmented region can be fully recycled. 

## Pointer Lookup
Each pointer contains metadata about the region pointer and the object index. The region pointer is simply a 62 KB aligned pointer with the bottom bits chopped off - we can directly expand it and access the region header without any layers of indirection. 
But how do we know where the object is within the region? Since there are no object headers, the data will appear as just a contiguous blob of bytes without a clear differentiator to search by. 
We instead rely on the region header to efficiently locate a particular object. The region header maintains a smallest_object_id and a bitset graveyard of collected objects which have now been compacted into. 


## (Almost) Pauseless
This overall approach is nearly pauseless, but not completely. Since processes are independently continuing to communicate with each other and do useful work, they may share a reference after we’ve looked through the work-queue for a process. Instead of suspending all work during GC, we enqueue a “pause” request at the end of each process queue before reading it. Any further references passed to it would appear after that “pause” request. If the GC completes its cycle before the process gets to that pause, it can cancel that pause request and the worker never has to know a GC took place. If the work-queue is shallow or the worker throughput is high, it can still encounter the pause request before it is canceled. This approach keeps the GC fairly independent from the scheduler, without requiring any special privileges or coordination between the two. 
Additionally, memory allocation itself has inherent pauses while we get memory from the system.


## Trade offs
The minimum region size and object size ensures we can reference all objects with our pointer format. This trades off wasting extra spaces for singleton classes, which may not have many objects under them.
By allocating per-class regions and using our pointer schema, we reduce the overhead of per-object headers. This makes small objects much more lightweight, and is great for data structures like trees and linked lists. We instead rely on object pointers to reference the region header, where the class metadata is found. 
We tradeoff extra computation on lookups for greater cache efficiency from compactness.


## Immutability
This entire approach is only possible due to the immutability guarantees of the language. Immutability allows us to reason about change and manage it. When anything can change under you, you have to stop-the-world to invoke a “temporary” immutable state of the application that you can concurrently modify in GC. With immutability, we get those concurrency guarantees out of the box without coordination. 

