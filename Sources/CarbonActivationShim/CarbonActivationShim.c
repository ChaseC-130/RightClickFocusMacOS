#include "CarbonActivationShim.h"

#include <ApplicationServices/ApplicationServices.h>

int32_t RightClickFocusActivateProcessForPID(pid_t pid) {
    ProcessSerialNumber processSerialNumber;
    OSStatus processResult = GetProcessForPID(pid, &processSerialNumber);
    if (processResult != noErr) {
        return processResult;
    }

    return SetFrontProcessWithOptions(
        &processSerialNumber,
        kSetFrontProcessCausedByUser
    );
}
