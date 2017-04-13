//
//  MessagingViewController.m
//  MyMessenger
//
//  Created by SendBird Developers on 12/5/15.
//  Copyright © 2015 SENDBIRD.COM. All rights reserved.
//

#import "MessagingViewController.h"
#import "MessagingSystemMessageTableViewCell.h"
#import "MessagingBroadcastMessageTableViewCell.h"
#import "MessagingMessageTableViewCell.h"
#import "MessagingOpponentMessageTableViewCell.h"
#import "MessagingFileLinkTableViewCell.h"
#import "MessageOpponentFileLinkTableViewCell.h"

@interface MessagingViewController ()<UITableViewDataSource, UITableViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate> {
    SendBirdMessagingChannel *currentChannel;
    NSMutableArray *messages;
    BOOL isLoadingMessage;
    BOOL firstTimeLoading;
    BOOL openImagePicker;
    long long lastMessageTimestamp;
    long long firstMessageTimestamp;
    NSMutableDictionary *typeStatus;
    NSMutableDictionary *readStatus;
    BOOL scrollLocked;
    NSTimer *typingIndicatorTimer;
}

@end

@implementation MessagingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    
    isLoadingMessage = NO;
    firstTimeLoading = YES;
    lastMessageTimestamp = LLONG_MIN;
    firstMessageTimestamp = LLONG_MAX;
    scrollLocked = NO;
    
    messages = [[NSMutableArray alloc] init];
    
    [self.sendFileButton.layer setBorderColor:[[UIColor blueColor] CGColor]];
    [self.sendMessageButton.layer setBorderColor:[[UIColor blueColor] CGColor]];
    [self.messageTextField.layer setBorderColor:[[UIColor blueColor] CGColor]];
    
    [self.messagingTableView setDelegate:self];
    [self.messagingTableView setDataSource:self];
    [self.messagingTableView setSeparatorColor:[UIColor clearColor]];
    [self.messagingTableView setContentInset:UIEdgeInsetsMake(0, 0, 12, 0)];
    
    [self.prevMessageLoadingIndicator setHidden:YES];
    
    [self hideTyping];
    
    [self.messageTextField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [self.messageTextField setDelegate:self];
    
    [self.navigationBarTitle setTitle:[MyUtils generateMessagingTitle:currentChannel]];
    
   [SendBird loginWithUserId:[SendBird deviceUniqueID] andUserName:[MyUtils getUserName] andUserImageUrl:[MyUtils getUserProfileImage] andAccessToken:@""];
   [SendBird registerNotificationHandlerMessagingChannelUpdatedBlock:^(SendBirdMessagingChannel *channel) {
      if ([SendBird getCurrentChannel] != nil && [[SendBird getCurrentChannel] channelId] == [channel getId]) {
         [self updateMessagingChannel:channel];
      }
   }
                                                 mentionUpdatedBlock:^(SendBirdMention *mention) {
                                                    
                                                 }];
   [SendBird setEventHandlerConnectBlock:^(SendBirdChannel *channel) {
      [SendBird markAsRead];
   } errorBlock:^(NSInteger code) {
      
   } channelLeftBlock:^(SendBirdChannel *channel) {
      
   } messageReceivedBlock:^(SendBirdMessage *message) {
      if (lastMessageTimestamp < [message getMessageTimestamp]) {
         lastMessageTimestamp = [message getMessageTimestamp];
      }
      
      if (firstMessageTimestamp > [message getMessageTimestamp]) {
         firstMessageTimestamp = [message getMessageTimestamp];
      }
      
      if ([message isPast]) {
         [messages insertObject:message atIndex:0];
      }
      else {
         [messages addObject:message];
      }
      [self scrollToBottomWithReloading:YES animated:NO];
      
      [SendBird markAsRead];
   } systemMessageReceivedBlock:^(SendBirdSystemMessage *message) {
      if (lastMessageTimestamp < [message getMessageTimestamp]) {
         lastMessageTimestamp = [message getMessageTimestamp];
      }
      
      if (firstMessageTimestamp > [message getMessageTimestamp]) {
         firstMessageTimestamp = [message getMessageTimestamp];
      }
      
      if ([message isPast]) {
         [messages insertObject:message atIndex:0];
      }
      else {
         [messages addObject:message];
      }
      [self scrollToBottomWithReloading:YES animated:NO];
      
      [SendBird markAsRead];
   } broadcastMessageReceivedBlock:^(SendBirdBroadcastMessage *message) {
      if (lastMessageTimestamp < [message getMessageTimestamp]) {
         lastMessageTimestamp = [message getMessageTimestamp];
      }
      
      if (firstMessageTimestamp > [message getMessageTimestamp]) {
         firstMessageTimestamp = [message getMessageTimestamp];
      }
      
      if ([message isPast]) {
         [messages insertObject:message atIndex:0];
      }
      else {
         [messages addObject:message];
      }
      [self scrollToBottomWithReloading:YES animated:NO];
      
      [SendBird markAsRead];
   } fileReceivedBlock:^(SendBirdFileLink *fileLink) {
      if (lastMessageTimestamp < [fileLink getMessageTimestamp]) {
         lastMessageTimestamp = [fileLink getMessageTimestamp];
      }
      
      if ([fileLink isPast]) {
         [messages insertObject:fileLink atIndex:0];
      }
      else {
         [messages addObject:fileLink];
      }
      [self scrollToBottomWithReloading:YES animated:NO];
      
      [SendBird markAsRead];
   } messagingStartedBlock:^(SendBirdMessagingChannel *channel) {
      currentChannel = channel;
      [self updateMessagingChannel:channel];
      
      [[SendBird queryMessageListInChannel:[currentChannel getUrl]] prevWithMessageTs:LLONG_MAX andLimit:50 resultBlock:^(NSMutableArray *queryResult) {
         for (SendBirdMessage *message in queryResult) {
            if ([message isPast]) {
               [messages insertObject:message atIndex:0];
            }
            else {
               [messages addObject:message];
            }
            
            if (lastMessageTimestamp < [message getMessageTimestamp]) {
               lastMessageTimestamp = [message getMessageTimestamp];
            }
            
            if (firstMessageTimestamp > [message getMessageTimestamp]) {
               firstMessageTimestamp = [message getMessageTimestamp];
            }
         }
         [self scrollToBottomWithReloading:YES animated:NO];
         [SendBird joinChannel:[currentChannel getUrl]];
         scrollLocked = NO;
         [SendBird connectWithMessageTs:LLONG_MAX];
      } endBlock:^(NSError *error) {
         
      }];
   } messagingUpdatedBlock:^(SendBirdMessagingChannel *channel) {
      currentChannel = channel;
      [self updateMessagingChannel:channel];
   } messagingEndedBlock:^(SendBirdMessagingChannel *channel) {
      
   } allMessagingEndedBlock:^{
      
   } messagingHiddenBlock:^(SendBirdMessagingChannel *channel) {
      
   } allMessagingHiddenBlock:^{
      
   } readReceivedBlock:^(SendBirdReadStatus *status) {
      [self setReadStatus:[[status user] guestId] andTimestamp:[status timestamp]];
      [self.messagingTableView reloadData];
   } typeStartReceivedBlock:^(SendBirdTypeStatus *status) {
      [self setTypeStatus:[[status user] guestId] andTimestamp:[status timestamp]];
      [self showTyping];
   } typeEndReceivedBlock:^(SendBirdTypeStatus *status) {
      [self setTypeStatus:[[status user] guestId] andTimestamp:0];
      [self showTyping];
   } allDataReceivedBlock:^(NSUInteger sendBirdDataType, int count) {
      
   } messageDeliveryBlock:^(BOOL send, NSString *message, NSString *data, NSString *messageId) {
      
   }];
   [SendBird joinMessagingWithChannelUrl:[currentChannel getUrl]];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)startTimer
{
   if (typingIndicatorTimer != nil) {
      [typingIndicatorTimer invalidate];
   }
   
   typingIndicatorTimer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(clearTypingIndicator:) userInfo:nil repeats:NO];
}

- (void)clearTypingIndicator:(NSTimer *)timer
{
   [self hideTyping];
}

- (void)setMessagingChannel:(SendBirdMessagingChannel *)ch
{
    currentChannel = ch;
}

- (IBAction)closeMessaging:(id)sender {
    [SendBird disconnect];
    [[self delegate] prepareCloseMessagingViewController];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)leaveMessaging:(id)sender {
    [SendBird endMessagingWithChannelUrl:[currentChannel getUrl]];
    [SendBird disconnect];
    [[self delegate] prepareCloseMessagingViewController];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)keyboardWillShow:(NSNotification*)notif
{
    NSDictionary *keyboardInfo = [notif userInfo];
    NSValue *keyboardFrameEnd = [keyboardInfo valueForKey:UIKeyboardFrameEndUserInfoKey];
    CGRect keyboardFrameEndRect = [keyboardFrameEnd CGRectValue];
    [self.inputViewBottomMargin setConstant:keyboardFrameEndRect.size.height];
    [self.view updateConstraints];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self scrollToBottomWithReloading:NO animated:NO];
    });
}

- (void)keyboardWillHide:(NSNotification*)notification
{
    [self.inputViewBottomMargin setConstant:0];
    [self.view updateConstraints];
    [self scrollToBottomWithReloading:NO animated:NO];
}

- (void)scrollToBottomWithReloading:(BOOL)reload animated:(BOOL)animated
{
    if (reload) {
        [self.messagingTableView reloadData];
    }
    
    if (scrollLocked) {
        return;
    }
    
    unsigned long msgCount = [messages count];
    if (msgCount > 0) {
        [self.messagingTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:(msgCount - 1) inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:animated];
    }
}

- (void) loadPreviousMessages {
   if (isLoadingMessage) {
      return;
   }
   isLoadingMessage = YES;
   
   [self.prevMessageLoadingIndicator setHidden:NO];
   [self.prevMessageLoadingIndicator startAnimating];
   [[SendBird queryMessageListInChannel:[currentChannel getUrl]] prevWithMessageTs:firstMessageTimestamp andLimit:50 resultBlock:^(NSMutableArray *queryResult) {
      NSMutableArray *newMessages = [[NSMutableArray alloc] init];
      for (SendBirdMessage *message in queryResult) {
         if ([message isPast]) {
            [newMessages insertObject:message atIndex:0];
         }
         else {
            [newMessages addObject:message];
         }
         
         if (lastMessageTimestamp < [message getMessageTimestamp]) {
            lastMessageTimestamp = [message getMessageTimestamp];
         }
         
         if (firstMessageTimestamp > [message getMessageTimestamp]) {
            firstMessageTimestamp = [message getMessageTimestamp];
         }
      }
      NSUInteger newMsgCount = [newMessages count];
      
      if (newMsgCount > 0) {
         [messages insertObjects:newMessages atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, newMsgCount)]];
         
         dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.messagingTableView reloadData];
            if ([newMessages count] > 0) {
               [self.messagingTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:([newMessages count] - 1) inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
            }
            isLoadingMessage = NO;
            [self.prevMessageLoadingIndicator setHidden:YES];
            [self.prevMessageLoadingIndicator stopAnimating];
         });
      }
      else {
         isLoadingMessage = NO;
         [self.prevMessageLoadingIndicator setHidden:YES];
         [self.prevMessageLoadingIndicator stopAnimating];
      }
   } endBlock:^(NSError *error) {
      isLoadingMessage = NO;
      [self.prevMessageLoadingIndicator setHidden:YES];
      [self.prevMessageLoadingIndicator stopAnimating];
   }];
}

- (IBAction)clickSendFileButton:(id)sender {
    UIImagePickerController *mediaUI = [[UIImagePickerController alloc] init];
    mediaUI.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    NSMutableArray *mediaTypes = [[NSMutableArray alloc] initWithObjects:(NSString *)kUTTypeImage, nil];
    mediaUI.mediaTypes = mediaTypes;
    [mediaUI setDelegate:self];
    openImagePicker = YES;
    [self presentViewController:mediaUI animated:YES completion:nil];
}

- (void) sendMessage
{
   NSString *message = [self.messageTextField text];
   if ([message length] > 0) {
      [self.messageTextField setText:@""];
      [SendBird sendMessage:message];
      [SendBird typeEnd];
   }
   scrollLocked = NO;
}

- (IBAction)clickSendMessageButton:(id)sender {
    [self sendMessage];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self sendMessage];
    
    return YES;
}

- (void) textFieldDidChange:(UITextView *)textView
{
   if ([[textView text] length] > 0) {
      [SendBird typeStart];
   }
   else {
      [SendBird typeEnd];
   }
}

- (void) setTypeStatus:(NSString *)userId andTimestamp:(long long)ts
{
    if ([userId isEqualToString:[SendBird getUserId]]) {
        return;
    }
   
    if (typeStatus == nil) {
        typeStatus = [[NSMutableDictionary alloc] init];
    }
    
    if(ts <= 0) {
        [typeStatus removeObjectForKey:userId];
    } else {
        [typeStatus setObject:[NSNumber numberWithLongLong:ts] forKey:userId];
    }
}

- (void) showTyping
{
   if ([typeStatus count] == 0) {
      [self hideTyping];
   }
   else {
      [self.typingIndicatorView setHidden:NO];
      [self.typeStatusLabel setHidden:NO];
      self.typingIndicatorHeight.constant = 48;
      [self.view updateConstraints];
      
      [self scrollToBottomWithReloading:NO animated:NO];
      
      [self.typeStatusLabel setText:[MyUtils generateTypingStatus:typeStatus]];
   }
   [self startTimer];
}

- (void) hideTyping
{
    [self.typingIndicatorView setHidden:YES];
    [self.typeStatusLabel setHidden:YES];
    self.typingIndicatorHeight.constant = 0;
    [self.view updateConstraints];
}

- (void) setReadStatus:(NSString *)userId andTimestamp:(long long)ts
{
   if (readStatus == nil) {
      readStatus = [[NSMutableDictionary alloc] init];
   }
   
   if ([readStatus objectForKey:userId] == nil) {
      [readStatus setObject:[NSNumber numberWithLongLong:ts] forKey:userId];
   }
   else {
      long long oldTs = [[readStatus objectForKey:userId] longLongValue];
      if (oldTs < ts) {
         [readStatus setObject:[NSNumber numberWithLongLong:ts] forKey:userId];
      }
   }
}

- (void) updateMessagingChannel:(SendBirdMessagingChannel *)channel
{
   [self.navigationBarTitle setTitle:[MyUtils generateMessagingTitle:currentChannel]];
   
   NSMutableDictionary *newReadStatus = [[NSMutableDictionary alloc] init];
   for (SendBirdMemberInMessagingChannel *member in [channel members]) {
      NSNumber *currentStatus = [readStatus objectForKey:[member guestId]];
      if (currentStatus == nil) {
         currentStatus = [NSNumber numberWithLongLong:0];
      }
      [newReadStatus setObject:[NSNumber numberWithLongLong:MAX([currentStatus longLongValue], [channel getLastReadMillis:[member guestId]])] forKey:[member guestId]];
   }
   
   if (readStatus == nil) {
      readStatus = [[NSMutableDictionary alloc] init];
   }
   [readStatus removeAllObjects];
   for (NSString *key in newReadStatus) {
      id value = [newReadStatus objectForKey:key];
      [readStatus setObject:value forKey:key];
   }
   [self.messagingTableView reloadData];
}

#pragma mark - Navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.destinationViewController isKindOfClass:[MessagingMembersInChannelViewController class]]) {
        MessagingMembersInChannelViewController *vc = (MessagingMembersInChannelViewController *)segue.destinationViewController;
        [vc setSendBirdMessagingChannel:currentChannel];
    }
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [messages count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([indexPath section] == 0) {
        UITableViewCell *commonCell = nil;
        SendBirdMessageModel *msgModel = (SendBirdMessageModel *)[messages objectAtIndex:[indexPath row]];
        
        if ([msgModel isKindOfClass:[SendBirdMessage class]]) {
            SendBirdMessage *msg = (SendBirdMessage *)msgModel;
            if ([[[msg sender] guestId] isEqualToString:[SendBird getUserId]]) {
                MessagingMessageTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MessagingMessageCell"];
                [cell setReadStatus:readStatus];
                [cell setMessage:(SendBirdMessage *)msgModel];
                commonCell = cell;
            }
            else {
                MessagingOpponentMessageTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MessagingOpponentMessageCell"];
                [cell setMessage:(SendBirdMessage *)msgModel];
                commonCell = cell;
            }
        }
        else if ([msgModel isKindOfClass:[SendBirdBroadcastMessage class]]) {
            MessagingBroadcastMessageTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MessagingBroadcastMessageCell"];
            [cell setBroadcastMessage:(SendBirdBroadcastMessage *)msgModel];
            commonCell = cell;
        }
        else if ([msgModel isKindOfClass:[SendBirdSystemMessage class]]) {
            MessagingSystemMessageTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MessagingSystemMessageCell"];
            [cell setSystemMessage:(SendBirdSystemMessage *)msgModel];
            commonCell = cell;
        }
        else if ([msgModel isKindOfClass:[SendBirdFileLink class]]) {
            SendBirdFileLink *msg = (SendBirdFileLink *)msgModel;
            if ([[[msg sender] guestId] isEqualToString:[SendBird getUserId]]) {
                MessagingFileLinkTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MessagingFileLinkCell"];
                [cell setReadStatus:readStatus];
                [cell setFileMessage:(SendBirdFileLink *)msgModel];
                commonCell = cell;
            }
            else {
                MessageOpponentFileLinkTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MessagingOpponentFileLinkCell"];
                [cell setFileMessage:(SendBirdFileLink *)msgModel];
                commonCell = cell;
            }
        }
        
        if ([indexPath row] == 0) {
            [self loadPreviousMessages];
        }
        
        if ([indexPath row] == [messages count] - 1) {
            scrollLocked = NO;
        }
        
        [commonCell setNeedsLayout];
        
        return commonCell;
    }
    else {
        return nil;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return nil;
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == [messages count] - 1) {
        scrollLocked = YES;
    }
}

- (void) scrollViewDidScroll:(UIScrollView *)scrollView
{
    scrollLocked  = YES;
    [self.view endEditing:YES];
}

#pragma mark - UITableViewDelegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([indexPath section] == 0) {
        CGFloat height = 0;
        SendBirdMessageModel *msgModel = (SendBirdMessageModel *)[messages objectAtIndex:[indexPath row]];
        
        if ([msgModel isKindOfClass:[SendBirdMessage class]]) {
            SendBirdMessage *msg = (SendBirdMessage *)msgModel;
            if ([[[msg sender] guestId] isEqualToString:[SendBird getUserId]]) {
                MessagingMessageTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MessagingMessageCell"];
                [cell setMessage:(SendBirdMessage *)msgModel];
                 height = [cell getCellHeight];
            }
            else {
                MessagingOpponentMessageTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MessagingOpponentMessageCell"];
                [cell setMessage:(SendBirdMessage *)msgModel];
                 height = [cell getCellHeight];
            }
        }
        else if ([msgModel isKindOfClass:[SendBirdBroadcastMessage class]]) {
            MessagingBroadcastMessageTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MessagingBroadcastMessageCell"];
            [cell setBroadcastMessage:(SendBirdBroadcastMessage *)msgModel];
            height = [cell getCellHeight];
        }
        else if ([msgModel isKindOfClass:[SendBirdSystemMessage class]]) {
            MessagingSystemMessageTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MessagingSystemMessageCell"];
            [cell setSystemMessage:(SendBirdSystemMessage *)msgModel];
            height = [cell getCellHeight];
        }
        else if ([msgModel isKindOfClass:[SendBirdFileLink class]]) {
            SendBirdFileLink *msg = (SendBirdFileLink *)msgModel;
            if ([[[msg sender] guestId] isEqualToString:[SendBird getUserId]]) {
                MessagingFileLinkTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MessagingFileLinkCell"];
                [cell setFileMessage:(SendBirdFileLink *)msgModel];
                height = [cell getCellHeight];
            }
            else {
                MessageOpponentFileLinkTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MessagingOpponentFileLinkCell"];
                [cell setFileMessage:(SendBirdFileLink *)msgModel];
                height = [cell getCellHeight];
            }
        }

        return height;;
    }
    else {
        return 64;
    }
}

#pragma mark - UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
   __block NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
   __block UIImage *originalImage, *editedImage, *imageToUse;
   __block NSURL *imagePath;
   __block NSString *imageName;
   
   [picker dismissViewControllerAnimated:YES completion:^{
      if (CFStringCompare ((CFStringRef) mediaType, kUTTypeImage, 0) == kCFCompareEqualTo) {
         editedImage = (UIImage *) [info objectForKey:
                                    UIImagePickerControllerEditedImage];
         originalImage = (UIImage *) [info objectForKey:
                                      UIImagePickerControllerOriginalImage];
         
         if (originalImage) {
            imageToUse = originalImage;
         } else {
            imageToUse = editedImage;
         }
         
         NSData *imageFileData = UIImagePNGRepresentation(imageToUse);
         imagePath = [info objectForKey:@"UIImagePickerControllerReferenceURL"];
         imageName = [imagePath lastPathComponent];
         
         [SendBird uploadFile:imageFileData type:@"image/jpg" hasSizeOfFile:[imageFileData length] withCustomField:@"" uploadBlock:^(SendBirdFileInfo *fileInfo, NSError *error) {
            openImagePicker = NO;
            [SendBird sendFile:fileInfo];
         }];
      }
   }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:^{
        openImagePicker = NO;
    }];
}

@end
