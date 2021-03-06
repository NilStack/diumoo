//
//  DMDoubanAuthHelper.m
//  diumoo
//
//  Created by Shanzi on 12-6-9.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "DMDoubanAuthHelper.h"
#import "DMErrorLog.h"

static DMDoubanAuthHelper* sharedHelper;

@implementation DMDoubanAuthHelper
@synthesize username,icon,userinfo,promotion_chls,recent_chls,userUrl;
@synthesize playedSongsCount,likedSongsCount,bannedSongsCount;


#pragma class methods

+(DMDoubanAuthHelper*) sharedHelper
{
    if(sharedHelper == nil) {
        sharedHelper = [[DMDoubanAuthHelper alloc] init];
    }
    return sharedHelper;
}

+(NSString*) getNewCaptchaCode
{    
    NSError* error;
    NSString* code = [NSString stringWithContentsOfURL:[NSURL URLWithString:@"https://douban.fm/j/new_captcha"]
                                              encoding:NSASCIIStringEncoding 
                                                 error:&error];
    if(error != nil){
        [DMErrorLog logErrorWith:self method:_cmd andError:error];
        return @"";
    }
    
    return [code stringByReplacingOccurrencesOfString:@"\"" withString:@""];
}

#pragma -

#pragma dealloc


#pragma -

#pragma public methods

-(NSError*) authWithDictionary:(NSDictionary *)dict
{
    NSString* authStringBody = [self stringEncodedForAuth:dict];
    
    NSMutableURLRequest* authRequest =nil;
    if(authStringBody)
    {
        [self logoutAndCleanData];
        NSData* authRequestBody = [authStringBody dataUsingEncoding:NSUTF8StringEncoding];
        authRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:AUTH_STRING]];
        [authRequest setHTTPMethod:@"POST"];
        [authRequest setHTTPBody:authRequestBody];
    }
    else
    {
        authRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:DOUBAN_FM_INDEX]];
        [authRequest setHTTPMethod:@"GET"];
    }

    //[authRequest setTimeoutInterval:20.0];
    
    
    // 发出同步请求
    NSURLResponse *response;
    NSError *error = [[NSError alloc] initWithDomain:@"diumoo" code:0 userInfo:nil];
	NSData *data = [NSURLConnection sendSynchronousRequest:authRequest
                                         returningResponse:&response
                                                     error:&error];
    
    if(error.code != 0){
        [DMErrorLog logErrorWith:self method:_cmd andError:error];
        if (data != nil) {
            NSLog(@"%@",data);
        }
        //[self logoutAndCleanData];
        return nil;
    }
    
    return [self connectionResponseHandlerWithResponse:response andData:data];
    
}
-(void) logoutAndCleanData
{
    username = nil;
    userUrl = nil;
    userinfo = nil;
    icon = nil;
    promotion_chls = nil;
    recent_chls = nil;
    
    NSArray* cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
    
    for (NSHTTPCookie* cookie in cookies) {
        if([cookie.domain isEqualToString:@".douban.fm"])
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
    }
    
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"isPro"];
    [[NSUserDefaults standardUserDefaults] setInteger:64 forKey:@"musicQuality"];
    
    
    [[NSNotificationCenter defaultCenter] postNotificationName:AccountStateChangedNotification 
                                                        object:self];
}

-(NSImage*) getUserIcon
{
    if(userinfo && icon) {
        return icon;
    }
    return [NSImage imageNamed:NSImageNameUser];
}

#pragma -

#pragma private methods

-(void) fetchPromotionAndRecentChannel
{
    NSURL* promotion_url = [NSURL URLWithString:PROMOTION_CHLS_URL];
    NSURL* recent_url = [NSURL URLWithString:RECENT_CHLS_URL];
    NSURLRequest* promotion_request = [NSURLRequest requestWithURL:promotion_url
                                       cachePolicy:NSURLCacheStorageAllowed
                                                   timeoutInterval:10.0
                                       ];
    NSURLRequest* recent_request = [NSURLRequest requestWithURL:recent_url
                                                    cachePolicy:NSURLCacheStorageAllowed
                                                timeoutInterval:10.0
                                    ];
    NSData* promotion_data = [NSURLConnection sendSynchronousRequest:promotion_request
                                                   returningResponse:nil
                                                               error:nil];
    NSData* recent_data = [NSURLConnection sendSynchronousRequest:recent_request
                                                returningResponse:nil
                                                            error:nil];
    
    if (promotion_data) {
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:promotion_data options:NSJSONReadingMutableContainers error:nil];
        if (dict && dict[@"status"]) {
            promotion_chls = dict[@"data"][@"chls"];
        }
    }
    
    if (recent_data) {
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:recent_data options:NSJSONReadingMutableContainers error:nil];

        if (dict && dict[@"status"]) {
            recent_chls = dict[@"data"][@"chls"];
        }
    }
}

-(void) loginSuccessWithUserinfo:(NSDictionary*) info
{
    [self fetchPromotionAndRecentChannel];
    
    username = [info valueForKey:@"name"];
    userUrl = [info valueForKey:@"url"];
    userinfo = info;
    isPro = [[info valueForKey:@"is_pro"] boolValue];
    
    
    NSString* _id = [info valueForKey:@"id"];
    if (_id) {
        NSString* iconstring = [NSString stringWithFormat: @"http://img3.douban.com/icon/u%@.jpg",_id];
        icon = [[NSImage alloc] initWithContentsOfURL:[NSURL URLWithString:iconstring]];
    }
    else {
        icon = [NSImage imageNamed:NSImageNameUser];
    }
    
    [[NSUserDefaults standardUserDefaults] setBool:isPro forKey:@"isPro"];
    if (!isPro) 
        [[NSUserDefaults standardUserDefaults] setInteger:64 forKey:@"musicQuality"];
    else
        [[NSUserDefaults standardUserDefaults] setValue:
         [[NSUserDefaults standardUserDefaults] valueForKey:@"pro_musicQuality"]
                                                 forKey:@"musicQuality"];
    
    
    [[NSNotificationCenter defaultCenter] postNotificationName:AccountStateChangedNotification 
                                                        object:self];
}

-(NSString*) stringEncodedForAuth:(NSDictionary *)dict
{
    // 检查参数是否正确，正确的话，返回预处理过的stringbody
    // 否则返回 nil
    
    NSString *name = [dict valueForKey:kAuthAttributeUsername];
    NSString *password = [dict valueForKey:kAuthAttributePassword];
    NSString *captcha = [dict valueForKey:kAuthAttributeCaptchaSolution];
    NSString *captchacode = [dict valueForKey:kAuthAttributeCaptchaCode];
    
    if ([name length] && [password length] && [captcha length] && [captchacode length]) {
        return [NSString stringWithFormat:@"remember=on&source=radio&%@",[dict urlEncodedString]];
    }
    
    return nil;
}


-(NSString*) user_id
{
    NSURL* url = [NSURL URLWithString:DOUBAN_FM_INDEX];
    NSArray* cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:url];
    
    
    for (NSHTTPCookie* cookie in cookies) {
        if ([[cookie name] isEqualToString:@"dbcl2"]) {
            NSString* dbcl2 = [cookie value];
            NSArray* array = [dbcl2 componentsSeparatedByString:@":"];
            if ([array count]>1) {
                NSString* _id = array[0];
                return [_id stringByReplacingOccurrencesOfString:@"\"" withString:@""];
            }
        }
    }
    return nil;
}

-(NSDictionary*) tryParseHtmlForAuthWithData:(NSData*) data
{
    NSError* herr=nil;
    HTMLParser* parser = [[HTMLParser alloc] initWithData:data error:&herr];
    if(herr == nil)
    {
        BOOL is_pro=NO;
        HTMLNode* bodynode=[parser body];
        
        HTMLNode* total=[bodynode findChildWithAttribute:@"id" matchingName:@"rec_played" allowPartial:NO];
        HTMLNode* liked=[bodynode findChildWithAttribute:@"id" matchingName:@"rec_liked" allowPartial:NO];
        HTMLNode* banned=[bodynode findChildWithAttribute:@"id" matchingName:@"rec_banned" allowPartial:NO];
        HTMLNode* user=[bodynode findChildWithAttribute:@"id" matchingName:@"user_name" allowPartial:NO];
        HTMLNode* pro_icon=[bodynode findChildOfClass:@"pro_icon"];
 
        NSString* user_id = [self user_id];
        
        
        if(user && user_id){
            if (pro_icon) is_pro=YES;
            NSString* userlink = [@"http://www.douban.com/people/" stringByAppendingString:user_id];
            NSString* name = [user contents];
            NSRegularExpression* whitespace = [NSRegularExpression
                                               regularExpressionWithPattern:@"(^\\s+|\\s+$)"
                                               options:NSRegularExpressionCaseInsensitive
                                               error:nil];
            name = [whitespace stringByReplacingMatchesInString:name
                                                 options:0
                                                   range:NSMakeRange(0, [name length])
                                            withTemplate:@""];
            NSDictionary* play_record = @{
                                          @"played": (total==nil?@(0):[total contents]),
                                          @"liked": (liked==nil?@(0):[liked contents]),
                                          @"banned": (banned==nil ? @(0) : [banned contents])
                                          };
            
            NSDictionary* user_info=@{
            @"name": name ,
            @"play_record": play_record,
            @"url": userlink,
            @"id":user_id,
            @"is_pro":@(is_pro),
            };
            
            return user_info ;
        }
    }
    return nil;
}


-(NSError*) connectionResponseHandlerWithResponse:(NSURLResponse*) response andData:(NSData*) data
{
    NSError* jerr = nil;
    
    NSDictionary *obj = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jerr];

    if(jerr){
        // 返回的内容不能解析成json，尝试解析HTML获得用户登陆信息
        NSDictionary* info = [self tryParseHtmlForAuthWithData:data];
        if (info) {
            // 登陆成功，此时无需重新记录cookie
            [self loginSuccessWithUserinfo:info];
        }
        else {
            // 登陆失败
            NSError *error = [NSError errorWithDomain:@"DM Auth Error" code:-1 userInfo:nil];
            [DMErrorLog logErrorWith:self method:_cmd andError:error];
            return error;
        }
    }
    else {
        // json解析成功
        if([[obj valueForKey:@"r"] intValue] == 0){
            // 登陆成功
            // 将cookie记录下来
            NSArray *cookies = [NSHTTPCookie 
                                cookiesWithResponseHeaderFields:
                                [response  performSelector:@selector(allHeaderFields)]
                                forURL:[response URL]] ;
            
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookies:cookies
                                                               forURL:[NSURL URLWithString:DOUBAN_FM_INDEX]
                                                      mainDocumentURL:nil];
            
            
            [self loginSuccessWithUserinfo:[obj valueForKey:@"user_info"]];
        }
        else {
            // 登陆失败
            NSError *error = [NSError errorWithDomain:@"DM Auth Error" code:-2
                                             userInfo:[obj valueForKey:@"err_msg"]];
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"isPro"];
            [[NSUserDefaults standardUserDefaults] setInteger:64 forKey:@"musicQuality"];

            return error;
        }
    }
    return nil;
}

#pragma -

@end
