//
//  QMIncomingCallController.m
//  Q-municate
//
//  Created by Igor Alefirenko on 08/04/2014.
//  Copyright (c) 2014 Quickblox. All rights reserved.
//

#import "QMIncomingCallController.h"
#import "QMApi.h"
#import "QMImageView.h"
#import "QMSoundManager.h"

@interface QMIncomingCallController ()

@property (weak, nonatomic) IBOutlet UILabel *userNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *incomingCallLabel;
@property (weak, nonatomic) IBOutlet QMImageView *userAvatarView;
@property (weak, nonatomic) IBOutlet UIButton *acceptButton;

@property (copy, nonatomic) NSString *sessionID;

@end

@implementation QMIncomingCallController

@synthesize opponent;
@synthesize sessionID;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.userAvatarView.imageViewType = QMImageViewTypeCircle;
    
    opponent = [[QMApi instance] userWithID:self.opponentID];
    
    self.userNameLabel.text = opponent ? opponent.fullName : @"Unknown caller";
 
    if (self.callType == QBVideoChatConferenceTypeAudioAndVideo) {
        self.incomingCallLabel.text = NSLocalizedString(@"QM_STR_INCOMING_VIDEO_CALL", nil);
        [self.acceptButton setImage:[ UIImage imageNamed:@"answer-video"] forState:UIControlStateNormal];
    } else if (self.callType == QBVideoChatConferenceTypeAudio) {
        self.incomingCallLabel.text = NSLocalizedString(@"QM_STR_INCOMING_CALL", nil);
        [self.acceptButton setImage:[ UIImage imageNamed:@"answer"] forState:UIControlStateNormal];
    }

    [self.userAvatarView sd_setImageWithURL:[NSURL URLWithString:opponent.website] placeholderImage:[UIImage imageNamed:@"upic_call"]];

    [QMSoundManager playRingtoneSound];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    
    [[QMSoundManager shared] stopAllSounds];
}

#pragma mark - Actions

- (IBAction)acceptCall:(id)sender {
    
    [[QMSoundManager shared] stopAllSounds];
    if (self.callType == QBVideoChatConferenceTypeAudioAndVideo) {
        [self performSegueWithIdentifier:kStartVideoCallSegueIdentifier sender:nil];
    } else {
        [self performSegueWithIdentifier:kStartAudioCallSegueIdentifier sender:nil];
    }
}

- (IBAction)declineCall:(id)sender {
    
    [[QMSoundManager shared] stopAllSounds];
    [[QMApi instance] rejectCallFromUser:opponent ? self.opponent.ID : self.opponentID  opponentView:nil];
    [QMSoundManager playEndOfCallSound];
    self.incomingCallLabel.text = NSLocalizedString(@"QM_STR_CALL_WAS_CANCELLED", nil);
    
    [self performSelector:@selector(dismissCallsController) withObject:self afterDelay:2.0f];
} 

- (void)dismissCallsController {
    
    [[QMSoundManager shared] stopAllSounds];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)setCallStatus:(NSString *)callStatus {
    
    if (![self.incomingCallLabel isEqual:callStatus]) {
        self.incomingCallLabel.text = callStatus;
    }
}

@end
