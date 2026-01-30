//
//  SafePluginRegistrant.h
//  Runner
//
//  Güvenli plugin kaydı için Objective-C wrapper
//

#import <Flutter/Flutter.h>

NS_ASSUME_NONNULL_BEGIN

@interface SafePluginRegistrant : NSObject

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry;

@end

NS_ASSUME_NONNULL_END

