//
//  WPAuthHandler.m
//  Simplenote
//  Handles oauth authentication with WordPress.com
//

#import <Foundation/Foundation.h>
#import "WPAuthHandler.h"
#import "SPConstants.h"
#import "SPTracker.h"

@implementation WPAuthHandler

+ (BOOL)isWPAuthenticationUrl:(NSURL*)url {
    return [[url host] isEqualToString:@"auth"];
}

+ (SPUser *)authorizeSimplenoteUserFromUrl:(NSURL*)url forAppId:(NSString *)appId {
    if (url == nil || appId == nil) {
        return nil;
    }
    
    NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:url
                                                resolvingAgainstBaseURL:NO];
    NSArray *queryItems = urlComponents.queryItems;
    NSString *state = [self valueForKey:@"state" fromQueryItems:queryItems];
    NSString *user = [self valueForKey:@"user" fromQueryItems:queryItems];
    NSString *token = [self valueForKey:@"token" fromQueryItems:queryItems];
    NSString *wpcomToken = [self valueForKey:@"wp_token" fromQueryItems:queryItems];
    NSString *errorCode = [self valueForKey:@"code" fromQueryItems:queryItems];
    
    if (state == nil || user == nil || token == nil) {
        NSDictionary *errorInfo;
        if (errorCode != nil && [errorCode isEqualToString:@"1"]) {
            NSString *errorMessage = NSLocalizedString(@"Please activate your WordPress.com account via email and try again.", @"Error message displayed when user has not verified their WordPress.com account");
            errorInfo = [NSDictionary dictionaryWithObject:errorMessage forKey:@"errorString"];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:SPSignInErrorNotificationName
                                                            object:nil
                                                          userInfo:errorInfo];
        [SPTracker trackWPCCLoginFailed];
        return false;
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *storedState = [defaults stringForKey:@"SPAuthSessionKey"];
    if (![state isEqualToString: storedState]) {
        // States don't match!
        [[NSNotificationCenter defaultCenter] postNotificationName:SPSignInErrorNotificationName
                                                            object:nil];
        [SPTracker trackWPCCLoginFailed];
        return nil;
    }
    
    [defaults removeObjectForKey:@"SPAuthSessionKey"];
    [defaults setObject:user forKey:@"SPUsername"];
    NSError *error = nil;
    BOOL success = [SPKeychain setPassword:token forService:appId account:user error:&error];
    if (success == NO) {
        [[NSNotificationCenter defaultCenter] postNotificationName:SPSignInErrorNotificationName
                                                            object:nil];
        [SPTracker trackWPCCLoginFailed];
        return nil;
    }
    
    // Store wpcom token for future integrations
    if (wpcomToken != nil) {
        [SPKeychain setPassword:token forService:SPWPServiceName account:user error:&error];
    }
    
    SPUser *spUser = [[SPUser alloc] initWithEmail:user token:token];
    return spUser;
}

+ (NSString *)valueForKey:(NSString *)key fromQueryItems:(NSArray *)queryItems
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name=%@", key];
    NSURLQueryItem *queryItem = [[queryItems filteredArrayUsingPredicate:predicate] firstObject];
    return queryItem.value;
}

@end
