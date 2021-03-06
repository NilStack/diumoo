//
//  DMDoubanAuthHelper.h
//  diumoo
//
//  Created by Shanzi on 12-6-9.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//
#define kAuthAttributeUsername @"alias"
#define kAuthAttributePassword @"form_password"
#define kAuthAttributeCaptchaSolution @"captcha_solution"
#define kAuthAttributeCaptchaCode @"captcha_id"

#define AccountStateChangedNotification @"accountstatechanged"
#define AUTH_STRING @"https://douban.fm/j/login"
#define DOUBAN_FM_INDEX @"https://douban.fm/account/switch_version?san=0&error=1"
#define PROMOTION_CHLS_URL @"https://douban.fm/j/explore/promotion_chls"
#define RECENT_CHLS_URL @"https://douban.fm/j/explore/recent_chls"


#import <Foundation/Foundation.h>
#import "NSDictionary+UrlEncoding.h"
#import "HTMLParser.h"

@interface DMDoubanAuthHelper : NSObject
{   
    NSString *username;
    NSString *userUrl;
    NSImage  *icon;
    NSDictionary *userinfo;
    
    BOOL isPro;
}

@property(copy,readonly) NSString *username;
@property(copy,readonly) NSString *userUrl;
@property(readonly) NSImage *icon;
@property(readonly) NSDictionary *userinfo;
@property(readonly) NSArray * promotion_chls;
@property(readonly) NSArray * recent_chls;
@property NSInteger playedSongsCount;
@property NSInteger likedSongsCount;
@property NSInteger bannedSongsCount;

+(DMDoubanAuthHelper*) sharedHelper;
+(NSString*) getNewCaptchaCode; 

-(NSError*) authWithDictionary:(NSDictionary*) dict;
-(void) logoutAndCleanData;
-(NSImage*) getUserIcon;


@end
