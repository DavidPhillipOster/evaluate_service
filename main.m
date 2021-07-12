//  Created by David Phillip Oster on 8/6/11.
//  Apache 2 License

#import <AppKit/AppKit.h>

#import "EvaluateService.h"

int main(int argc, char *argv[]) {
  @autoreleasepool {
    EvaluateService *service = [[EvaluateService alloc] init];
    NSRegisterServicesProvider(service, @"EvaluateService");
    [[NSRunLoop currentRunLoop] run];
  }
  return 0;
}
