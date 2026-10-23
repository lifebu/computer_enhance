# TODO
## Curr
https://www.computerenhance.com/p/table-of-contents
- Moving Data
- Later I should go through the QA to get more information :3

# Introduction: Five Multipliers
- Improve Performance: Reduce (A) number- and (B) speed of instructions.
- Five multipliers: Total = Waste * IPC * SIMD * Caching * MT.
## 1st: Waste: (A) 
- Reduce waste: Do less work that is not part of the core logic (cleanup, interpretter overhead).
## 2nd: IPC: "Instruction Parallelism" (B)
- IPC = Instructions-Per-Clock, ILP = Instruction-Level-Parallelism.
- ILP by parallelizing instructions that are not dependant on each other.
- Avoid serial-dependenncy-chains, by using domain knowledge.
## 3rd: SIMD: "Data Parallelism" (A)
- Reduce instructions by working on multiple data at once. 
- SIMD has bit width (e.g. 128bit) divided into lanes (e.g. 4 slots), which have a data size (e.g. 32-bit)
    bit width = data size * lane count.
    => Lower data size => more parallel lanes.
- We specify the absence of a dependency-chain between the SIMD lanes.
    - So the cpu does not need to deduce that.
    - BUT: Requires absence of dependency (which operations might not have).
## 4th: Caching: "Load Parallelism" (B)
- Loads from memory happen in units of one cache line (64Bytes).
- Cache hierarchy creates smaller, but faster memory on multiple levels.
- E.g.: Register File -> L1 (32kB, 4cyc) -> L2 (512kB, 12cyc) -> L3 (16MB, 70cyc) -> Main Memory
- Per core cache: L1, L2. Per cpu cache: L3. Fastest performance: all in L1 cache.
## 5th: Multithreading: "Thread Parallelism" (B)
- Multiple execution units (a core) with 2 hardware threads.
- Starting/Synchronizing threads has a considerable overhead, which adds to the total cost.
- Small work could be done on all threads instead of one thread + synchronize.
- More cores => more L1 cache => work on more data inside of L1.
- All-core loading might hid cpu-ram memory bandwidth limits => Limit to theoretical gain.

# Part1: 8086 ASM
## Curr
- Decoding Multiple Instructions and Suffixes

## Code
https://github.com/cmuratori/computer_enhance

zig build run -- upstream/perfaware/part1/listing_0037_single_register_mov
zig build test

zig build run -- upstream/perfaware/part1/listing_0037_single_register_mov > result.asm
nasm result.asm
diff upstream/perfaware/part1/listing_0037_single_register_mov result

testing:
zig build run -- upstream/perfaware/part1/listing_0039_more_movs > result.asm && nasm result.asm && diff result upstream/perfaware/part1/listing_0039_more_movs

## Tasks:
(second is always the challenge version).
0037-0038: mov
0039-0040: mov variants.
0041-0042: add_sub_cmp_jnz: p.165-p.166

## Doc
https://edge.edx.org/c4x/BITSPilani/EEE231/asset/8086_family_Users_Manual_1_.pdf
- P.160 Decoding.
- p.42 flags:
    
- 16-bit Registers. Memory-to-Register Movement.
    => Register names have 16-bit (AX), high-8-bit (AH) and low-8-bit variants (AL).
    MOV AX, BX => 16-bit, MOV AL, BL
- Instruction Decode: From byte encoding to actual work.
- Mnemonic = Human friendly name: MOV AX,BX = Move (Operand) from Bx (Source) to Ax (Destination).
- 8-bit Encoding: Opcode (6) + D-Flag (destination) + W-Flag (wide (16-bit))
- 8-bit Opcode Parameter: MOD-Field (2), REG-Field (3), RM-Field (3)
- 16-bit Displacement: Optional for memory data.
- 86 architecture: variable length: Each byte can tell us if there is one more byte after that for the same instruction.
- memory operation: mov bx, [address]
- x86 is little endian.
- effective address calculation: mov bx, [bp + 75] => displacement => defined by MOD-field
- MOD-field: do we have 1-byte or 2-byte displacement? means we have more bytes coming in.
- destination flag and memory: 1 == load (register is destination), 0 == store (register is source). 
- RM-Field: Encodes type of equation of effective address calculation.
    - (bx)+(si), (bx)+(di), (bp)+(si), (bp)+(di), (si), (di), (bp), (bx)  
    - with the MOD field you add d8 or d16 to it.
    - MOD == 0 and RM = 110 => 2 byte immediate direct address.
- Basic pattern for a lot of instructions:
    [Opcode DW][MOD REG R/M] DISP
    [Opcode W][MOD 000 R/M] IMM
    => Because of this you can bake in memory access into the operation (e.g. ADD with memory access).
- Arithmetic Commands:
    - Immediate mode version have [MOD XXX R/M] in the second byte.
    - the XXX is the actual arithmetic operation to do.
    - This means we have the same opcode for different arithmetic operations.
    - The same bit-pattern is used as the last 3 bits of the operand.
- Conditional Jump:
    - First byte: Patterns states which kind of jump (JNZ).
    - Second byte is 8-bit displacement.

# Part2: Haversine
## Code
https://github.com/cmuratori/computer_enhance
- listing 0065: haversine_formula

## RDTSC
- Total time measurement: not conclusive effidence of the effect of a change.
- RDTSC: Read Timestamp Counter Instruction
    - Writes 64-bit value in two 32-bit register.
    - Monotonically increasing overflowing cycle counter starting with cpu. Can be written to.
    - Take two measurements for delta. Note: RDTSC itself takes time! Average measurements to reduce error.
- CPU: Multicore with different frequencies (e.g. boost clocks).
    => RDTSC is based on global constant frequency (invariant TSC). Allows cross-core timing.
    - Cannot querry rdtsc frequency => Requires 2nd timer (e.g. OSTimer) to convert to real-time.
- rdtscp: rdtsc + it puts the PID (Processor-Core-ID) of the core doing the rdtsc into a register.

## Profiling
- Instrumentation-based profiling: Adding code to the program to get metrics.
- Sampling-based profiling: Does not change the original code.
- Profiling system goals: Easy to deploy, fairly accurate, low overhead. Extra: easy to interpret.

## Profiling Solutions
- gdmag: jonathan blows version: 
https://github.com/dwilliamson/GDMagArchive/tree/master/feb03/blow/gdmag_profiling_2
- casey: profile block retains starting time. elapsed time written back to anchor.
- iprof: write start timer value to anchor.
    - When block is opened it computes diff between parent start and now.
    - Diff is added to parent's time.
    - When the child block closes, it's parent's starting time is set to the current time.
        => parent computes diff for inclusive time.
        => computes differences value exclusive children.
    - Total time (with children) uses a unique id generate from the current block callstack.
    - It needs to add the values to the anchors only once when it walks those callstacks.
    
## Profiling overhead
- Measure and know how you are changing the performance of the target. Very costly to add a lot of performance markups.
- Total percentages will be skewed towards the most expensive markup.
- It should be easy to remove the profiling sections for this reason.
- Decide: What is most important to capture? Can we measure at a high enough level to not disrupt measurements?

# Part 3: Moving Data
## Next tasks:
- Repetition Testing:
    - Compress notes.
    - Homework: Create a repetition tester.
        - listings: 0103
        - Zig example: https://pastebin.com/PULjTUhY
    - Listings: 0102, 0104, 0105
- Monitoring OS Performance Counters
    - Compress notes
    - Homework: Find a linux tool like perfmon, that can give me the graph data.
- Page Faults:
    - Compress notes
    - Homework: Update repetition tester to show page faults, test count, byte count.
    - Listings: 0106, 0109
    - Note: On linux you will not get 4k pages readout, because linux has an optimization called "Transparent Huge Pages" (THP): Up to 2MByte pages. To disable this you need:
        #include <sys/prctl.h>
        prctl(PR_SET_THP_DISABLE, 1, 0, 0, 0);
    zig: std.os.linux.prctl();
- Page Faults: Probing OS Page Fault Behavior
    - Compress notes
    - Homework: Try to reproduce the behaviour of the OS pre filling pages by creating a csv and graphing it.
    - listing: 0112, 0113

## Measuring Data Throughput
- Speed upper bound: Data amount + Data speed.
- Diagram of functions (blocks) connecting with their supplied data (arrow).
    - How big are parts of the data? How expensive to read/write from/back system?
    - Compared to measured storage medium speeds.
    - Analyze parts of the diagram to educate yourself on specific behaviour.
- Add data amount to profiler block to measure throughput.

## Repetition Testing
- When you profile a lot of variables in the state of the system can change the outcome.
- Examples: what is in the file system cache of the OS? What is in the cache of the CPU?
- Use multiple repetitions (loop) to remove variability of the system.
- In each loop: keep running and keep the minimum.
- Have a timer: If I find a new minimum => reset the timer. If timer is done => stop.
- You can test multiple things in loop: Takes minimum of everything.
- Example File Read: Which way to open a file is most efficient?

## Monitoring OS Performance Counters
- Goal: Learn how to find out what you don't know and how to get enough information to educate yourself about this.
- If you find discrepencies with your tests (repetition) and the application, try to find any element that could create a difference or variation (variable). Eliminate variables.
    - Even if you time the same element, external factors can change the timings (like when how you allocate).
- Use OS software to get more detailed information on what happens from the OS side
    - Best to have something to visualize (in graph form!).
    - For this having a repetition test that continuously running in the background is very useful.
        - So when changes in the graph happen you can correlate that with the output of the program and what it is doing at that moment.
    - windows: perfmon.
    - linux: ??? grafana prometheus and process-exporter ???

## Page Fault
- Virtual Memory: If we exceed total amount of memory in systems we can react to that, does not need a crash.
- Memory protection: applications cannot read memory from other applications or trash memory.
- Virtual address, virtual to physical address translation, each process has it's own address translation tables, TLB cache for address translation
- OS has to manage the memory translation tables and where the virtual adress will map to.
- Pages: Fixed chunks of memory (windows: 4k), that the OS manages for translation. Everything is put chunks of the page size.
- All OS allocations are done in page size chunks.
- malloc is doing memory management for the chunks that are not 4k (if you request 1byte).
- OS manages pages by lazy evaluation: Only when you read/write to virtual memory the first time will it be mapped to physical memory.
- Page fault: When you write to virtual memory that has not been mapped yet, the OS will get an interrupt from the cpu for a page fault and react to it. If the address is legal (allocated before), it will provision physical memory.
- Segmentation fault: If the interrupt does not get to an legal virtual adress.
- If you are writing to a larger chunk memory (iterating over it), the OS will trigger a page fault for every page. Which costs you for each roundtrip each time you touch the page for the first time.
- Reads might react the same way as writes to unmapped virtual address.
    - But it could also just always return 0, because you have never written to it.
    - It seems linux does that?
- Measuring the number of page faults:
    - listing: 0106 : New metrics functions: ReadOSPageFaultCount and InitializeOSMetrics.
    - linux: getrusage(who, *rusage)
        - rusage is a struct with minflt (minor fault) and majflt (major fault)
        - major fault: had to go to actuall disc, otherwise minor.
        - who is std.os.linux.rusage.SELF (or THREAD or CHILDREN).
    - windows: GetProcessMemoryInfo
        - one param is a struct that cointains PageFaultCount
        - Requires a special process handle you get from OpenProces with:
            - PROCESS_QUERY_INFORMATION | PROCESS_VM_READ flags
            - GetCurrentProcessId() (zig: std.os.windows.GetCurrentProcessId())
    - listing 0109: Repetition tester now also measures page faults, byte count and test count.
            
## Page Fault: Probing Os Page Fault Behavior
- What is the page fault counter? How often the CPU interrupt happened? How many pages the cpu thinks we are going to touch? OS could map more then one page in one page fault (~pre fetching).
- We can test what the OS does by probing this behaviour by measuring page faults after different accesses of memory.
- malloc itself might do some management itself and prefill the data which breaks page fault testing.
=> Use direct syscall from the OS to allocate:
    - windows: VirtualAlloc <-> VirtualFree
    - linux: mmap <-> munmap
- listing 0112, listing 0113
- print out your values as comma seperated lines (csv). Which you can then open in any tabular programm (excel, etc.).
    - Values can be integers, but also strings in order to write headers.
    => Use that to graph things.
    Pipe the output of the program into a .csv file!
- Windows seems to optimize going through a buffer linearly in memory order by mapping multiple pages at a time.
- 
