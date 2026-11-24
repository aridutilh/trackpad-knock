// knock: play a short pattern on the Force Touch trackpad's haptic motor.
// Technique from os6/nospeaker and asadm/mechpad (private MultitouchSupport API).
// Build: clang -O2 -fobjc-arc -framework Foundation knock.m -o knock
// Usage: knock [done|ask|error]
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <unistd.h>

typedef CFArrayRef (*CreateList)(void);
typedef int32_t (*GetID)(void *, uint64_t *);
typedef bool (*IsBuiltIn)(void *);
typedef CFTypeRef (*ActuatorCreate)(uint64_t);
typedef int32_t (*ActuatorOpen)(CFTypeRef);
typedef int32_t (*ActuatorClose)(CFTypeRef);
typedef CFTypeRef (*ActuationCreate)(CFDictionaryRef, int32_t);
typedef int32_t (*ActuationPlay)(CFTypeRef, CFTypeRef, uint32_t, float, float);

static void *lib;
static void *sym(const char *n) {
    void *p = dlsym(lib, n);
    if (!p) { fprintf(stderr, "missing symbol %s\n", n); exit(1); }
    return p;
}
static CFTypeRef motor;
static ActuationCreate actuationCreate;
static ActuationPlay actuationPlay;

// One hit: a gaussian thump plus one or two sine tones.
static void hit(double base, double baseMS, NSArray<NSArray<NSNumber *> *> *tones) {
    NSMutableArray *t = [NSMutableArray array];
    for (NSArray<NSNumber *> *x in tones)
        [t addObject:@{@"Type": @"Sine", @"FrequencykHz": @(x[0].doubleValue / 1000.0),
                       @"Amplitude": x[1], @"DurationMS": x[2], @"DelayMS": @0.0}];
    NSDictionary *shape = @{@"BaseWaveform": @{@"Type": @"Gaussian", @"Amplitude": @(base), @"DurationMS": @(baseMS)},
                            @"Tones": t};
    CFTypeRef a = actuationCreate((__bridge CFDictionaryRef)shape, 0);
    if (!a) return;
    actuationPlay(a, motor, 0, 1.0f, 0);
    CFRelease(a);
}
static void waitMS(int ms) { usleep(ms * 1000); }

int main(int argc, char **argv) {
    @autoreleasepool {
        lib = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW);
        if (!lib) { fprintf(stderr, "MultitouchSupport not available\n"); return 1; }
        CreateList createList = sym("MTDeviceCreateList");
        GetID getID = sym("MTDeviceGetDeviceID");
        IsBuiltIn isBuiltIn = sym("MTDeviceIsBuiltIn");
        ActuatorCreate actuatorCreate = sym("MTActuatorCreateFromDeviceID");
        ActuatorOpen actuatorOpen = sym("MTActuatorOpen");
        ActuatorClose actuatorClose = sym("MTActuatorClose");
        actuationCreate = sym("MTActuationCreateFromDictionary");
        actuationPlay = sym("MTActuationActuate");

        CFArrayRef list = createList();
        if (!list || CFArrayGetCount(list) == 0) { fprintf(stderr, "no trackpad found\n"); return 1; }
        // Built-in trackpad first, then external ones.
        for (int pass = 0; pass < 2 && !motor; pass++) {
            for (CFIndex i = 0; i < CFArrayGetCount(list) && !motor; i++) {
                void *dev = (void *)CFArrayGetValueAtIndex(list, i);
                if (isBuiltIn(dev) != (pass == 0)) continue;
                uint64_t devID = 0;
                if (getID(dev, &devID) != 0) continue;
                CFTypeRef ref = actuatorCreate(devID);
                if (ref && actuatorOpen(ref) == 0) motor = ref;
                else if (ref) CFRelease(ref);
            }
        }
        if (!motor) { fprintf(stderr, "no Force Touch actuator could be opened\n"); return 1; }

        NSString *p = argc > 1 ? @(argv[1]) : @"done";
        if ([p isEqual:@"done"]) {            // two knocks on wood
            for (int i = 0; i < 2; i++) { hit(0.5, 12, @[@[@180, @0.3, @22], @[@420, @0.2, @10]]); waitMS(140); }
        } else if ([p isEqual:@"ask"]) {      // three rising ticks: the agent needs you
            for (NSNumber *hz in @[@300, @450, @650]) { hit(0.3, 8, @[@[hz, @0.6, @35]]); waitMS(110); }
        } else if ([p isEqual:@"error"]) {    // one long low buzz
            hit(0.4, 20, @[@[@110, @0.6, @180]]);
        } else { fprintf(stderr, "usage: knock [done|ask|error]\n"); return 1; }
        waitMS(250);
        actuatorClose(motor);
        CFRelease(motor);
    }
    return 0;
}
