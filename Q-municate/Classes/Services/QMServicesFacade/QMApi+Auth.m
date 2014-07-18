//
//  QMApi+Auth.m
//  Qmunicate
//
//  Created by Andrey on 03.07.14.
//  Copyright (c) 2014 Quickblox. All rights reserved.
//

#import "QMApi.h"
#import "QMAuthService.h"
#import "QMFacebookService.h"
#import "QMChatService.h"
#import "QMSettingsManager.h"
#import "QMContent.h"

@implementation QMApi (Auth)

- (void)logout {
    
    [self.settingsManager clearSettings];
    [self.chatService logout];
    [self.facebookService logout];
    [self cleanUp];
}

- (void)setAutoLogin:(BOOL)autologin {
    self.settingsManager.rememberMe = autologin;
}

- (void)loginWithFacebook:(void(^)(BOOL success))completion {
    
    __weak __typeof(self)weakSelf = self;
    
    [self.facebookService connectToFacebook:^(NSString *sessionToken) {
        
        if (!sessionToken) {
            completion(NO);
            return;
        }
        
        [weakSelf.authService createSessionWithBlock:^(QBAAuthSessionCreationResult *result) {
            
            if([weakSelf checkResult:result]) {
                /*Open FBSession if needed*/
                
                /*Login with facebook*/
                [weakSelf.authService logInWithFacebookAccessToken:sessionToken completion:^(QBUUserLogInResult *loginWithFBResult) {
                    
                    if ([weakSelf checkResult:loginWithFBResult]) {
                        [weakSelf setAutoLogin:YES];
                        
                        if (weakSelf.settingsManager.pushNotificationsEnabled) {
                            [weakSelf.authService subscribeToPushNotifications];
                        }
                        
                        weakSelf.currentUser = loginWithFBResult.user;
                        
                        [weakSelf.chatService loginWithUser:loginWithFBResult.user completion:^(BOOL success) {
                            completion(success);
                            return;
                            if (loginWithFBResult.user.website.length == 0) {
                                /*Upload image from facebook to qbserver if needed*/
                                [weakSelf updateUserAvatarFromFacebook:^(QBUUserResult *result) {
                                    
                                    weakSelf.currentUser.website = result.user.website;
                                    completion(result.success);
                                    return;
                                }];
                            }
                            completion(YES);
                        }]; //Chat Login With user
                        
                    } else {
                        completion(NO);
                    }
                }]; // loginin with facebook
                
            } else {
                completion(NO);
            }
        }]; // Create session
    }]; // Connect to facebook
}

- (void)signUpAndLoginWithUser:(QBUUser *)user userAvatar:(UIImage *)userAvatar completion:(QBUUserResultBlock)completion {
    
    __weak __typeof(self)weakSelf = self;
    
    [self.authService createSessionWithBlock:^(QBAAuthSessionCreationResult *result) {
        
        if([weakSelf checkResult:result]) {
            
            [weakSelf.authService signUpUser:user completion:^(QBUUserResult *signUpResult) {
                
                if ([weakSelf checkResult:signUpResult]) {
                    
                    [weakSelf loginWithUser:user completion:^(QBUUserLogInResult *loginResult) {
                        
                        if (userAvatar) {
                            NSString *imageName = [NSString stringWithFormat:@"%d", loginResult.user.ID];
                            [weakSelf updateUserAvatar:userAvatar imageName:imageName completion:completion];
                        }
                        
                        completion(loginResult);
                    }];
                } else {
                    completion(signUpResult);
                }
            }];
        }
    }];
}

- (void)loginWithUser:(QBUUser *)user completion:(QBUUserLogInResultBlock)complition {
    
    
    if (self.settingsManager.rememberMe) {
        
        [self.settingsManager setLogin:user.email andPassword:user.password];
    }
    
    __weak __typeof(self)weakSelf = self;
    
    [self.authService createSessionWithBlock:^(QBAAuthSessionCreationResult *result) {
        
        if([weakSelf checkResult:result]) {
            
            [weakSelf.authService logInWithEmail:user.email password:user.password completion:^(QBUUserLogInResult *loginResult) {
                
                loginResult.user.password = user.password;
                weakSelf.currentUser = loginResult.user;
                
                if ([weakSelf checkResult:loginResult]) {
                    [weakSelf.authService subscribeToPushNotifications];
                    
                    [weakSelf.chatService loginWithUser:loginResult.user completion:^(BOOL success) {
                        
                        if (success) {
                            complition (loginResult);
                        } else {
                            NSAssert(NO, @"Update it");
                        }
                    }];
                }
            }];
        }
    }];
}

#pragma mark - Update current User

- (void)updateUser:(QBUUser *)user completion:(void(^)(BOOL success))completion  {
    
    NSString *password = user.password;
    user.password = nil;
    
    __weak __typeof(self)weakSelf = self;
    [self.authService updateUser:user withCompletion:^(QBUUserResult *result) {
        
        if ([weakSelf checkResult:result]) {
            result.user.password = password;
            weakSelf.currentUser = result.user;
        }
        
        completion(result.success);
    }];
}

- (void)changePasswordForCurrentUser:(QBUUser *)currentUser completion:(void(^)(BOOL success))completion {
    
    __weak __typeof(self)weakSelf = self;
    [self updateUser:currentUser completion:^(BOOL success) {
        
        if (success) {
            [weakSelf.settingsManager setLogin:currentUser.login andPassword:currentUser.password];
        }
        completion(success);
    }];
}

- (void)updateUserAvatarFromFacebook:(QBUUserResultBlock)completion {
    
    __weak __typeof(self)weakSelf = self;
    [self.facebookService loadUserImageWithUserID:self.currentUser.facebookID completion:^(UIImage *fbImage) {
        
        if (fbImage) {
            [weakSelf updateUserAvatar:fbImage imageName:weakSelf.currentUser.facebookID completion:completion];
        }
    }];
}

- (void)updateUserAvatar:(UIImage *)image imageName:(NSString *)imageName completion:(QBUUserResultBlock)completion {
    
    QMContent *content = [[QMContent alloc] init];
    __weak __typeof(self)weakSelf = self;
    [content uploadImage:image named:imageName completion:^(QBCFileUploadTaskResult *result) {
        
        if ([weakSelf checkResult:result]) {
            
            QBUUser *user = weakSelf.currentUser;
            user.oldPassword = user.password;
            user.website = [result.uploadedBlob publicUrl];
            
            [weakSelf.authService updateUser:user withCompletion:^(QBUUserResult *updateResult) {
                
                if ([weakSelf checkResult:updateResult]) {
                    
                    updateResult.user.password = weakSelf.currentUser.password;
                    weakSelf.currentUser = updateResult.user;
                }
                
                if (completion) completion(updateResult);
            }];
        }
    }];
}

- (void)resetUserPassordWithEmail:(NSString *)email completion:(void(^)(BOOL success))completion {
    
    __weak __typeof(self)weakSelf = self;
    [self.authService resetUserPasswordWithEmail:email completion:^(Result *result) {
        completion([weakSelf checkResult:result]);
    }];
}

- (void)destroySessionWithCompletion:(void(^)(BOOL success))completion {
    
    __weak __typeof(self)weakSelf = self;
    [self.authService destroySessionWithCompletion:^(QBAAuthResult *result) {
        completion([weakSelf checkResult:result]);
    }];
}

@end
