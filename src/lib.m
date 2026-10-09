#import <mach/mach.h>
#import <stdint.h>

void modifyCoinsToThousand(uintptr_t imageBase, uintptr_t staticManagerOffset, uintptr_t coinFieldOffset) {
    // Step 1: Resolve the static pointer to get the active manager instance
    // Base Address + Static Offset = Address where the instance pointer lives
    uintptr_t pointerAddress = imageBase + staticManagerOffset;
    uintptr_t managerInstance = *(uintptr_t *)pointerAddress;
    
    if (managerInstance == 0) {
        // The manager instance hasn't been created in memory yet (e.g., still on the main menu)
        return;
    }
    
    // Step 2: Add your small relative object offset to land directly on the coin variable
    uintptr_t coinAddress = managerInstance + coinFieldOffset;
    
    // Step 3: Ensure the memory page is writable, then write the new value
    mach_port_t task = mach_task_self();
    kern_return_t err;
    
    // Make the memory writable (VM_PROT_COPY ensures safety if it's copy-on-write)
    err = mach_vm_protect(task, (mach_vm_address_t)coinAddress, sizeof(int), FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    
    if (err == KERN_SUCCESS) {
        // Overwrite the existing coin count with 1000
        *(int *)coinAddress = 1000;
        
        // Optional: You can restore memory protection here if needed, 
        // but leaving it writable is standard for active game variable modifications.
    }
}