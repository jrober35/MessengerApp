//
//  OpenChatChattingViewController.m
//  MyMessenger
//
//  Created by SendBird Developers on 12/4/15.
//  Copyright © 2015 SENDBIRD.COM. All rights reserved.
//

#import "OpenChatChattingViewController.h"
#import "OpenChatMessageTableViewCell.h"
#import "OpenChatBroadcastTableViewCell.h"
#import "MessagingViewController.h"
#import "OpenChatFileMessageTableViewCell.h"

@interface OpenChatChattingViewController ()<UITableViewDataSource, UITableViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, MessagingViewControllerDelegate, UITextFieldDelegate>  {
    SendBirdChannel *currentChannel;
    NSMutableArray *messages;
    BOOL isLoadingMessage;
    BOOL openImagePicker;
    long long lastMessageTimestamp;
    long long firstMessageTimestamp;
    BOOL scrollLocked;
}

@end

@implementation OpenChatChattingViewController

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
    
    openImagePicker = NO;
    isLoadingMessage = NO;
    lastMessageTimestamp = LLONG_MIN;
    firstMessageTimestamp = LLONG_MAX;
    scrollLocked = NO;
    
    messages = [[NSMutableArray alloc] init];
    
    [self.navigationBarTitle setTitle:[currentChannel name]];
    [self.sendFileButton.layer setBorderColor:[[UIColor blueColor] CGColor]];
    [self.sendMessageButton.layer setBorderColor:[[UIColor blueColor] CGColor]];
    [self.messageTextField.layer setBorderColor:[[UIColor blueColor] CGColor]];
    
    [self.messageTextField setDelegate:self];
    
    [self.openChatChattingTableView setDelegate:self];
    [self.openChatChattingTableView setDataSource:self];
    [self.openChatChattingTableView setSeparatorColor:[UIColor clearColor]];
    
    [self.prevMessageLoadingIndicator setHidden:YES];
    
    [self startChattingWithPreviousMessage:YES];
}

- (void)startChattingWithPreviousMessage:(BOOL)tf
{
   [SendBird loginWithUserId:[SendBird deviceUniqueID] andUserName:[MyUtils getUserName] andUserImageUrl:[MyUtils getUserProfileImage] andAccessToken:@""];
   [SendBird joinChannel:[currentChannel url]];
   [SendBird setEventHandlerConnectBlock:^(SendBirdChannel *channel) {
      
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
   } systemMessageReceivedBlock:^(SendBirdSystemMessage *message) {
      
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
   } fileReceivedBlock:^(SendBirdFileLink *fileLink) {
      if (lastMessageTimestamp < [fileLink getMessageTimestamp]) {
         lastMessageTimestamp = [fileLink getMessageTimestamp];
      }
      
      if (firstMessageTimestamp > [fileLink getMessageTimestamp]) {
         firstMessageTimestamp = [fileLink getMessageTimestamp];
      }
      
      if ([fileLink isPast]) {
         [messages insertObject:fileLink atIndex:0];
      }
      else {
         [messages addObject:fileLink];
      }
      [self scrollToBottomWithReloading:YES animated:NO];
   } messagingStartedBlock:^(SendBirdMessagingChannel *channel) {
      UIStoryboard *storyboard = [self storyboard];
      MessagingViewController *vc = [storyboard instantiateViewControllerWithIdentifier:@"MessagingViewController"];
      [vc setMessagingChannel:channel];
      [vc setDelegate:self];
      [self presentViewController:vc animated:YES completion:nil];
   } messagingUpdatedBlock:^(SendBirdMessagingChannel *channel) {
      
   } messagingEndedBlock:^(SendBirdMessagingChannel *channel) {
      
   } allMessagingEndedBlock:^{
      
   } messagingHiddenBlock:^(SendBirdMessagingChannel *channel) {
      
   } allMessagingHiddenBlock:^{
      
   } readReceivedBlock:^(SendBirdReadStatus *status) {
      
   } typeStartReceivedBlock:^(SendBirdTypeStatus *status) {
      
   } typeEndReceivedBlock:^(SendBirdTypeStatus *status) {
      
   } allDataReceivedBlock:^(NSUInteger sendBirdDataType, int count) {
      
   } messageDeliveryBlock:^(BOOL send, NSString *message, NSString *data, NSString *messageId) {
      
   }];
   
   if (tf) {
      [[SendBird queryMessageListInChannel:[currentChannel url]] prevWithMessageTs:LLONG_MAX andLimit:50 resultBlock:^(NSMutableArray *queryResult) {
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
         scrollLocked = NO;
         [SendBird connectWithMessageTs:LLONG_MAX];
      } endBlock:^(NSError *error) {
         
      }];
   }
   else {
      [SendBird connect];
   }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[self navigationController] setNavigationBarHidden:YES animated:NO];
    if (!openImagePicker) {
        [SendBird disconnect];
    }
}

- (void)setChannel:(SendBirdChannel *)ch {
    currentChannel = ch;
}

- (IBAction)leaveChannel:(id)sender {
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
        [self.openChatChattingTableView reloadData];
    }
    
    if (scrollLocked) {
        return;
    }
    
    unsigned long msgCount = [messages count];
    if (msgCount > 0) {
        [self.openChatChattingTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:(msgCount - 1) inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:animated];
    }
}

- (void) loadPreviousMessages {
   if (isLoadingMessage) {
      return;
   }
   isLoadingMessage = YES;
   
   [self.prevMessageLoadingIndicator setHidden:NO];
   [self.prevMessageLoadingIndicator startAnimating];
   [[SendBird queryMessageListInChannel:[currentChannel url]] prevWithMessageTs:firstMessageTimestamp andLimit:50 resultBlock:^(NSMutableArray *queryResult) {
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
            [self.openChatChattingTableView reloadData];
            if ([newMessages count] > 0) {
               [self.openChatChattingTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:([newMessages count] - 1) inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
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

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

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
            OpenChatMessageTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OpenChatMessageCell"];
           
            [cell setMessage:(SendBirdMessage *)msgModel];
            
            commonCell = cell;
        }
        else if ([msgModel isKindOfClass:[SendBirdBroadcastMessage class]]) {
            OpenChatBroadcastTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OpenChatBroadcastCell"];
            [cell setBroadcastMessage:(SendBirdBroadcastMessage *)msgModel];
            commonCell = cell;
        }
        else if ([msgModel isKindOfClass:[SendBirdFileLink class]]) {
            OpenChatFileMessageTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OpenChatFileCell"];
            [cell setFileMessage:(SendBirdFileLink *)msgModel];
            commonCell = cell;
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
            OpenChatMessageTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OpenChatMessageCell"];
            
            [cell setMessage:(SendBirdMessage *)msgModel];
            height = [cell getCellHeight];
        }
        else if ([msgModel isKindOfClass:[SendBirdBroadcastMessage class]]) {
            OpenChatBroadcastTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OpenChatBroadcastCell"];
            [cell setBroadcastMessage:(SendBirdBroadcastMessage *)msgModel];
            height = [cell getCellHeight];
        }
        else if ([msgModel isKindOfClass:[SendBirdFileLink class]]) {
            OpenChatFileMessageTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OpenChatFileCell"];
            [cell setFileMessage:(SendBirdFileLink *)msgModel];
            height = [cell getCellHeight];
        }

        return height;
    }
    else {
        return 64;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
   UIAlertController *messageSubMenu;
   UIAlertAction *messageAction;
   UIAlertAction *messageCancelAction;
   
   if ([[messages objectAtIndex:indexPath.row] isKindOfClass:[SendBirdMessage class]]) {
      SendBirdMessage *message = (SendBirdMessage *)[messages objectAtIndex:indexPath.row];
      
      if ([[[message sender] guestId] isEqualToString:[SendBird getUserId]]) {
         return;
      }
      
      NSString *actionTitle = [NSString stringWithFormat:@"Start messaging with %@", [message getSenderName]];
      messageSubMenu = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
      messageAction = [UIAlertAction actionWithTitle:actionTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
         [SendBird startMessagingWithUserId:[[message sender] guestId]];
      }];
      messageCancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {}];
      [messageSubMenu addAction:messageAction];
      [messageSubMenu addAction:messageCancelAction];
      
      [self presentViewController:messageSubMenu animated:YES completion:nil];
   }
   else {
      return;
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

#pragma mark - MessagingViewControllerDelegate
- (void) prepareCloseMessagingViewController
{   
    [self startChattingWithPreviousMessage:NO];
}

@end
