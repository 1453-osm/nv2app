//
//  SafePluginRegistrant.m
//  Runner
//
//  Güvenli plugin kaydı için Objective-C wrapper
//  AltStore ile kurulumda Swift/Objective-C bridge sorunlarını önler
//

#import "SafePluginRegistrant.h"
#import "GeneratedPluginRegistrant.h"

#if __has_include(<audioplayers_darwin/AudioplayersDarwinPlugin.h>)
#import <audioplayers_darwin/AudioplayersDarwinPlugin.h>
#else
@import audioplayers_darwin;
#endif

@implementation SafePluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
    @try {
        // Önce diğer plugin'leri kaydet (audioplayers hariç)
        [self registerPluginsExceptAudioplayers:registry];
        
        // audioplayers plugin'ini ayrı olarak ve güvenli bir şekilde kaydet
        // Swift runtime'ın tam yüklenmesi için kısa bir gecikme
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self registerAudioplayersPlugin:registry];
        });
    } @catch (NSException *exception) {
        NSLog(@"Plugin kayıt hatası: %@", exception.reason);
        // Hata olsa bile uygulamanın çalışmaya devam etmesini sağla
    }
}

+ (void)registerPluginsExceptAudioplayers:(NSObject<FlutterPluginRegistry>*)registry {
    // audioplayers hariç diğer plugin'leri kaydet
    @try {
        // Firebase plugin'leri
        Class firestoreClass = NSClassFromString(@"FLTFirebaseFirestorePlugin");
        if (firestoreClass) {
            [firestoreClass registerWithRegistrar:[registry registrarForPlugin:@"FLTFirebaseFirestorePlugin"]];
        }
        
        Class firebaseCoreClass = NSClassFromString(@"FLTFirebaseCorePlugin");
        if (firebaseCoreClass) {
            [firebaseCoreClass registerWithRegistrar:[registry registrarForPlugin:@"FLTFirebaseCorePlugin"]];
        }
        
        // Diğer plugin'ler
        Class compassClass = NSClassFromString(@"FlutterCompassPlugin");
        if (compassClass) {
            [compassClass registerWithRegistrar:[registry registrarForPlugin:@"FlutterCompassPlugin"]];
        }
        
        Class notificationsClass = NSClassFromString(@"FlutterLocalNotificationsPlugin");
        if (notificationsClass) {
            [notificationsClass registerWithRegistrar:[registry registrarForPlugin:@"FlutterLocalNotificationsPlugin"]];
        }
        
        Class geocodingClass = NSClassFromString(@"GeocodingPlugin");
        if (geocodingClass) {
            [geocodingClass registerWithRegistrar:[registry registrarForPlugin:@"GeocodingPlugin"]];
        }
        
        Class geolocatorClass = NSClassFromString(@"GeolocatorPlugin");
        if (geolocatorClass) {
            [geolocatorClass registerWithRegistrar:[registry registrarForPlugin:@"GeolocatorPlugin"]];
        }
        
        Class pathProviderClass = NSClassFromString(@"PathProviderPlugin");
        if (pathProviderClass) {
            [pathProviderClass registerWithRegistrar:[registry registrarForPlugin:@"PathProviderPlugin"]];
        }
        
        Class permissionClass = NSClassFromString(@"PermissionHandlerPlugin");
        if (permissionClass) {
            [permissionClass registerWithRegistrar:[registry registrarForPlugin:@"PermissionHandlerPlugin"]];
        }
        
        Class sharedPrefsClass = NSClassFromString(@"SharedPreferencesPlugin");
        if (sharedPrefsClass) {
            [sharedPrefsClass registerWithRegistrar:[registry registrarForPlugin:@"SharedPreferencesPlugin"]];
        }
    } @catch (NSException *exception) {
        NSLog(@"Plugin kayıt hatası: %@", exception.reason);
    }
}

+ (void)registerAudioplayersPlugin:(NSObject<FlutterPluginRegistry>*)registry {
    @try {
        // audioplayers plugin'ini güvenli bir şekilde kaydet
        Class audioplayersClass = NSClassFromString(@"AudioplayersDarwinPlugin");
        if (audioplayersClass && [audioplayersClass respondsToSelector:@selector(registerWithRegistrar:)]) {
            [audioplayersClass registerWithRegistrar:[registry registrarForPlugin:@"AudioplayersDarwinPlugin"]];
            NSLog(@"Audioplayers plugin başarıyla kaydedildi");
        } else {
            NSLog(@"AudioplayersDarwinPlugin sınıfı bulunamadı veya kayıt metoduna erişilemiyor");
        }
    } @catch (NSException *exception) {
        NSLog(@"Audioplayers plugin kayıt hatası: %@", exception.reason);
        // Plugin kayıt hatası olsa bile uygulama çalışmaya devam eder
    }
}

@end

