#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOUSBHost/IOUSBHost.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static int property_number(io_registry_entry_t service, CFStringRef key) {
    CFTypeRef value = IORegistryEntryCreateCFProperty(service, key, kCFAllocatorDefault, 0);
    int number = -1;
    if (value && CFGetTypeID(value) == CFNumberGetTypeID()) {
        CFNumberGetValue(value, kCFNumberIntType, &number);
    }
    if (value) CFRelease(value);
    return number;
}

static BOOL has_ids(io_registry_entry_t service, int vendor, int product) {
    return property_number(service, CFSTR("idVendor")) == vendor &&
           property_number(service, CFSTR("idProduct")) == product;
}

static io_service_t find_superdrive(void) {
    io_iterator_t iterator = IO_OBJECT_NULL;
    kern_return_t kr = IOServiceGetMatchingServices(kIOMainPortDefault,
        IOServiceMatching("IOUSBHostDevice"), &iterator);
    if (kr != KERN_SUCCESS) return IO_OBJECT_NULL;
    io_service_t found = IO_OBJECT_NULL, service;
    while ((service = IOIteratorNext(iterator))) {
        if (has_ids(service, 0x05ac, 0x1500)) {
            if (found) {
                fprintf(stderr, "More than one Apple USB SuperDrive found; refusing reset.\n");
                IOObjectRelease(found);
                IOObjectRelease(service);
                found = IO_OBJECT_NULL;
                break;
            }
            found = service;
        } else {
            IOObjectRelease(service);
        }
    }
    IOObjectRelease(iterator);
    return found;
}

static io_service_t find_ts4_parent(io_service_t drive) {
    io_registry_entry_t node = IO_OBJECT_NULL;
    if (IORegistryEntryGetParentEntry(drive, kIOServicePlane, &node) != KERN_SUCCESS)
        return IO_OBJECT_NULL;
    while (node) {
        int product = property_number(node, CFSTR("idProduct"));
        if (property_number(node, CFSTR("idVendor")) == 0x2188 &&
            (product == 0x5511 || product == 0x5512)) {
            return node;
        }
        io_registry_entry_t parent = IO_OBJECT_NULL;
        kern_return_t kr = IORegistryEntryGetParentEntry(node, kIOServicePlane, &parent);
        IOObjectRelease(node);
        node = kr == KERN_SUCCESS ? parent : IO_OBJECT_NULL;
    }
    return IO_OBJECT_NULL;
}

int main(int argc, const char *argv[]) {
    if (argc != 2 || (strcmp(argv[1], "--probe") && strcmp(argv[1], "--reset"))) {
        fprintf(stderr, "Usage: ts4-hub-reset --probe | --reset\n");
        return 64;
    }
    @autoreleasepool {
        io_service_t drive = find_superdrive();
        if (!drive) {
            fprintf(stderr, "Exactly one Apple USB SuperDrive is required.\n");
            return 2;
        }
        io_service_t hub = find_ts4_parent(drive);
        IOObjectRelease(drive);
        if (!hub) {
            fprintf(stderr, "SuperDrive is not under a supported TS4 USB 2 hub; refusing reset.\n");
            return 3;
        }
        int product = property_number(hub, CFSTR("idProduct"));
        printf("SuperDrive parent is CalDigit TS4 USB 2 hub 0x%04x.\n", product);
        if (!strcmp(argv[1], "--probe")) {
            IOObjectRelease(hub);
            return 0;
        }
        if (geteuid() != 0) {
            fprintf(stderr, "Reset requires root privileges.\n");
            IOObjectRelease(hub);
            return 4;
        }
        NSError *error = nil;
        IOUSBHostDevice *device = [[IOUSBHostDevice alloc]
            initWithIOService:hub
                     options:IOUSBHostObjectInitOptionsDeviceCapture
                       queue:nil
                       error:&error
             interestHandler:nil];
        IOObjectRelease(hub);
        if (!device) {
            fprintf(stderr, "Could not capture TS4 hub: %s\n",
                error.localizedDescription.UTF8String ?: "unknown error");
            return 5;
        }
        // For a captured device, destroy resets it and re-registers its drivers.
        [device destroy];
        printf("Requested re-enumeration of the selected TS4 USB 2 hub.\n");
        return 0;
    }
}
