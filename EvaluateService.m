//  Created by David Phillip Oster on 8/6/11.
//  Apache 2 License

#import "EvaluateService.h"
#import "Expr.h"

#import <AppKit/AppKit.h>

@implementation EvaluateService

- (void)doEvaluateService:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error {
  NSArray *classes = [NSArray arrayWithObject:[NSString class]];
  if ( ! [pboard canReadObjectForClasses:classes options:@{}]) {
    *error = NSLocalizedString(@"Error: couldn't get text.", 0);
  } else {
    NSString *pboardString = [pboard stringForType:NSPasteboardTypeString];
    int inLength = (int)[pboardString length];
    if (0 == inLength) {
      *error = NSLocalizedString(@"Error: empty string.", 0);
    } else {
      NSString *result = [self evaluate:pboardString error:error];
      if ([result length]) {
        [pboard clearContents];
        [pboard writeObjects:@[result]];
      }
    }
  }
}

- (NSString *)evaluate:(NSString *)inString error:(NSString **)error {
  NSString *result = nil;
  int length = (int)[inString length];
  if (length) {
    result = [Expression evaluate:inString];
  }
  if (0 == [result length]) {
    *error = NSLocalizedString(@"Error: Couldn't evaluate.", 0);
  }
  return result;
}

@end
