#import <Foundation/Foundation.h>
#import <mach/mach.h>

/**
 * Patches the CanCollectCoins boolean field at a given BotController instance address.
 * 
 * @param botControllerInstance Pointer to the active BotController instance object in memory.
 * @return BOOL YES if successful, NO otherwise.
 */
BOOL patchCoinCollection(void *botControllerInstance) {
    if (botControllerInstance == NULL) {
        NSLog(@"[-] Error: BotController instance pointer is NULL.");
        return NO;
    }

    // Define the dumped offset
    uintptr_t coinOffset = 0x0173;
    
    // Calculate the exact target address (Instance Base + Field Offset)
    volatile BOOL *targetAddress = (volatile BOOL *)((uintptr_t)botControllerInstance + coinOffset);

    // Value to write (true / 1)
    BOOL newValue = YES;

    // Optional: Make the memory region writable if it's protected
    mach_port_t task = mach_task_self();
    vm_size_t pageSize = vm_page_size;
    vm_address_t pageAddress = (vm_address_t)((uintptr_t)targetAddress & ~(pageSize - 1));
    
    kern_return_t kr = vm_protect(task, pageAddress, pageSize, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
    if (kr != KERN_SUCCESS) {
        NSLog(@"[-] Warning: vm_protect failed with error %d. Attempting direct write...", kr);
    }

    // Perform the memory write safely
    @try {
        *targetAddress = newValue;
        NSLog(@"[+] SUCCESS: Wrote 'YES' to BotController + 0x0173 (Address: %p)", (void *)targetAddress);
        return YES;
    } @catch (NSException *exception) {
        NSLog(@"[-] EXCEPTION during memory write: %@ - %@", exception.name, exception.reason);
        return NO;
    }
}