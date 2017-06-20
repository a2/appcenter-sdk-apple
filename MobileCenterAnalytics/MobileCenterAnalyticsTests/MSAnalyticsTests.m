#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <OCHamcrestIOS/OCHamcrestIOS.h>

#import "MSMobileCenter.h"
#import "MSMobileCenterInternal.h"
#import "MSServiceAbstract.h"
#import "MSServiceInternal.h"

#import "MSAnalytics.h"
#import "MSAnalyticsPrivate.h"
#import "MSAnalyticsInternal.h"
#import "MSChannelDefault.h"
#import "MSEventLog.h"
#import "MSLogManagerDefault.h"
#import "MSMockAnalyticsDelegate.h"
#import "MSTestFrameworks.h"

static NSString *const kMSTypeEvent = @"event";
static NSString *const kMSTypePage = @"page";
static NSString *const kMSTestAppSecret = @"TestAppSecret";
static NSString *const kMSAnalyticsServiceName = @"Analytics";

@class MSMockAnalyticsDelegate;

@interface MSAnalyticsTests : XCTestCase <MSAnalyticsDelegate>

@end

@interface MSAnalytics ()

@end

@interface MSServiceAbstract ()

- (BOOL)isEnabled;

- (void)setEnabled:(BOOL)enabled;

@end

@implementation MSAnalyticsTests

- (void)tearDown {
  [super tearDown];
  [MSAnalytics resetSharedInstance];
}

#pragma mark - Tests

- (void)testValidateEventName {

  // If
  NSString *validEventName = @"validEventName";
  NSString *shortEventName = @"e";
  NSString *eventName256 = [NSString stringWithFormat:@"%@%@",
                            @"_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256",
                            @"_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_256_265_256_256_256_256_256_256"];
  NSString *nullableEventName = nil;
  NSString *emptyEventName = @"";
  NSString *tooLongEventName = [NSString stringWithFormat:@"%@%@%@%@",
                                @"tooLongEventNametooLongEventNametooLongEventNametooLongEventNametooLongEventNametooLongEventNametooLongEventNametooLongEventName",
                                @"tooLongEventNametooLongEventNametooLongEventNametooLongEventNametooLongEventNametooLongEventNametooLongEventNametooLongEventName",
                                @"tooLongEventNametooLongEventNametooLongEventNametooLongEventNametooLongEventNametooLongEventNametooLongEventNametooLongEventName",
                                @"tooLongEventNametooLongEventNametooLongEventNametooLongEventNametooLongEventNametooLongEventNametooLongEventNametooLongEventName"];

  // When
  BOOL valid = [[MSAnalytics sharedInstance] validateEventName:validEventName forLogType:kMSTypeEvent];
  BOOL validShortEventName = [[MSAnalytics sharedInstance] validateEventName:shortEventName forLogType:kMSTypeEvent];
  BOOL validEventName256 = [[MSAnalytics sharedInstance] validateEventName:eventName256 forLogType:kMSTypeEvent];
  BOOL validNullableEventName =
      [[MSAnalytics sharedInstance] validateEventName:nullableEventName forLogType:kMSTypeEvent];
  BOOL validEmptyEventName = [[MSAnalytics sharedInstance] validateEventName:emptyEventName forLogType:kMSTypeEvent];
  BOOL validTooLongEventName =
      [[MSAnalytics sharedInstance] validateEventName:tooLongEventName forLogType:kMSTypeEvent];

  // Then
  XCTAssertTrue(valid);
  XCTAssertTrue(validShortEventName);
  XCTAssertTrue(validEventName256);
  XCTAssertFalse(validNullableEventName);
  XCTAssertFalse(validEmptyEventName);
  XCTAssertFalse(validTooLongEventName);
}

- (void)testValidatePropertyType {
  const int maxPropertriesPerEvent = 5;
  NSString *longStringValue =
      [NSString stringWithFormat:@"%@", @"valueValueValueValueValueValueValueValueValueValueValueValueValue"];
  NSString *stringValue64 =
      [NSString stringWithFormat:@"%@", @"valueValueValueValueValueValueValueValueValueValueValueValueValu"];

  // Test valid properties
  // If
  NSDictionary *validProperties =
      @{ @"Key1" : @"Value1",
         stringValue64 : @"Value2",
         @"Key3" : stringValue64,
         @"Key4" : @"Value4",
         @"Key5" : @"" };

  // When
  NSDictionary *validatedProperties =
      [[MSAnalytics sharedInstance] validateProperties:validProperties forLogName:kMSTypeEvent andType:kMSTypeEvent];

  // Then
  XCTAssertTrue([validatedProperties count] == [validProperties count]);

  // Test too many properties in one event
  // If
  NSDictionary *tooManyProperties = @{
    @"Key1" : @"Value1",
    @"Key2" : @"Value2",
    @"Key3" : @"Value3",
    @"Key4" : @"Value4",
    @"Key5" : @"Value5",
    @"Key6" : @"Value6",
    @"Key7" : @"Value7"
  };

  // When
  validatedProperties =
      [[MSAnalytics sharedInstance] validateProperties:tooManyProperties forLogName:kMSTypeEvent andType:kMSTypeEvent];

  // Then
  XCTAssertTrue([validatedProperties count] == maxPropertriesPerEvent);

  // Test invalid properties
  // If
  NSDictionary *invalidKeysInProperties =
      @{ @"Key1" : @"Value1",
         @(2) : @"Value2",
         longStringValue : @"Value3",
         @"" : @"Value4" };

  // When
  validatedProperties = [[MSAnalytics sharedInstance] validateProperties:invalidKeysInProperties
                                                              forLogName:kMSTypeEvent
                                                                 andType:kMSTypeEvent];

  // Then
  XCTAssertTrue([validatedProperties count] == 1);

  // Test invalid values
  // If
  NSDictionary *invalidValuesInProperties = @{ @"Key1" : @"Value1", @"Key2" : @(2), @"Key3" : longStringValue };

  // When
  validatedProperties = [[MSAnalytics sharedInstance] validateProperties:invalidValuesInProperties
                                                              forLogName:kMSTypeEvent
                                                                 andType:kMSTypeEvent];

  // Then
  XCTAssertTrue([validatedProperties count] == 1);

  // Test mixed variant
  // If
  NSDictionary *mixedEventProperties = @{
    @"Key1" : @"Value1",
    @(2) : @"Value2",
    stringValue64 : @"Value3",
    @"Key4" : stringValue64,
    @"Key5" : @"Value5",
    @"Key6" : @(2),
    @"Key7" : longStringValue,
    @"Key8" : @""
  };

  // When
  validatedProperties = [[MSAnalytics sharedInstance] validateProperties:mixedEventProperties
                                                              forLogName:kMSTypeEvent
                                                                 andType:kMSTypeEvent];

  // Then
  XCTAssertTrue([validatedProperties count] == maxPropertriesPerEvent);
  XCTAssertNotNil([validatedProperties objectForKey:@"Key1"]);
  XCTAssertNotNil([validatedProperties objectForKey:stringValue64]);
  XCTAssertNotNil([validatedProperties objectForKey:@"Key4"]);
  XCTAssertNotNil([validatedProperties objectForKey:@"Key5"]);
  XCTAssertNotNil([validatedProperties objectForKey:@"Key8"]);
  XCTAssertNil([validatedProperties objectForKey:@"Key6"]);
  XCTAssertNil([validatedProperties objectForKey:@"Key7"]);
}

- (void)testApplyEnabledStateWorks {
  [[MSAnalytics sharedInstance] startWithLogManager:OCMProtocolMock(@protocol(MSLogManager))
                                          appSecret:kMSTestAppSecret];

  MSServiceAbstract *service = [MSAnalytics sharedInstance];

  [service setEnabled:YES];
  XCTAssertTrue([service isEnabled]);

  [service setEnabled:NO];
  XCTAssertFalse([service isEnabled]);

  [service setEnabled:YES];
  XCTAssertTrue([service isEnabled]);
}

- (void)testSettingDelegateWorks {
  id<MSAnalyticsDelegate> delegateMock = OCMProtocolMock(@protocol(MSAnalyticsDelegate));
  [MSAnalytics setDelegate:delegateMock];
  XCTAssertNotNil([MSAnalytics sharedInstance].delegate);
  XCTAssertEqual([MSAnalytics sharedInstance].delegate, delegateMock);
}

- (void)testAnalyticsDelegateWithoutImplementations {

  // If
  NSString *groupId = [[MSAnalytics sharedInstance] groupId];
  id<MSAnalyticsDelegate> delegateMock = OCMProtocolMock(@protocol(MSAnalyticsDelegate));
  [MSMobileCenter sharedInstance].sdkConfigured = NO;
  [MSMobileCenter start:kMSTestAppSecret withServices:@[ [MSAnalytics class] ]];
  NSMutableDictionary *channelsInLogManager =
      ((MSLogManagerDefault *)([MSAnalytics sharedInstance].logManager)).channels;
  MSChannelDefault *channelMock = channelsInLogManager[groupId] = OCMPartialMock(channelsInLogManager[groupId]);
  OCMStub([channelMock enqueueItem:[OCMArg any] withCompletion:[OCMArg any]]).andDo(^(NSInvocation *invocation) {
    id<MSLog> log = nil;
    [invocation getArgument:&log atIndex:2];
    for (id<MSChannelDelegate> delegate in channelMock.delegates) {

      // Call all channel delegate methods for testing.
      [delegate channel:channelMock willSendLog:log];
      [delegate channel:channelMock didSucceedSendingLog:log];
      [delegate channel:channelMock didFailSendingLog:log withError:nil];
    }
  });

  // When
  MSEventLog *eventLog = OCMClassMock([MSEventLog class]);
  [[MSAnalytics sharedInstance].logManager processLog:eventLog forGroupId:groupId];

  // Then
  OCMReject([delegateMock analytics:[MSAnalytics sharedInstance] willSendEventLog:eventLog]);
  OCMReject([delegateMock analytics:[MSAnalytics sharedInstance] didSucceedSendingEventLog:eventLog]);
  OCMReject([delegateMock analytics:[MSAnalytics sharedInstance] didFailSendingEventLog:eventLog withError:nil]);
}

- (void)testAnalyticsDelegateMethodsAreCalled {

  // If
  [MSAnalytics resetSharedInstance];
  NSString *groupId = [[MSAnalytics sharedInstance] groupId];
  id<MSAnalyticsDelegate> delegateMock = OCMProtocolMock(@protocol(MSAnalyticsDelegate));
  [MSMobileCenter sharedInstance].sdkConfigured = NO;
  [MSMobileCenter start:kMSTestAppSecret withServices:@[ [MSAnalytics class] ]];
  NSMutableDictionary *channelsInLogManager =
      ((MSLogManagerDefault *)([MSAnalytics sharedInstance].logManager)).channels;
  MSChannelDefault *channelMock = channelsInLogManager[groupId] = OCMPartialMock(channelsInLogManager[groupId]);
  OCMStub([channelMock enqueueItem:[OCMArg any] withCompletion:[OCMArg any]]).andDo(^(NSInvocation *invocation) {
    id<MSLog> log = nil;
    [invocation getArgument:&log atIndex:2];
    for (id<MSChannelDelegate> delegate in channelMock.delegates) {

      // Call all channel delegate methods for testing.
      [delegate channel:channelMock willSendLog:log];
      [delegate channel:channelMock didSucceedSendingLog:log];
      [delegate channel:channelMock didFailSendingLog:log withError:nil];
    }
  });

  // When
  [[MSAnalytics sharedInstance] setDelegate:delegateMock];
  MSEventLog *eventLog = OCMClassMock([MSEventLog class]);
  [[MSAnalytics sharedInstance].logManager processLog:eventLog forGroupId:groupId];

  // Then
  OCMVerify([delegateMock analytics:[MSAnalytics sharedInstance] willSendEventLog:eventLog]);
  OCMVerify([delegateMock analytics:[MSAnalytics sharedInstance] didSucceedSendingEventLog:eventLog]);
  OCMVerify([delegateMock analytics:[MSAnalytics sharedInstance] didFailSendingEventLog:eventLog withError:nil]);
}

- (void)testTrackEventWithoutProperties {

  // If
  __block NSString *name;
  __block NSString *type;
  NSString *expectedName = @"gotACoffee";
  id<MSLogManager> logManagerMock = OCMProtocolMock(@protocol(MSLogManager));
  OCMStub([logManagerMock processLog:[OCMArg isKindOfClass:[MSLogWithProperties class]] forGroupId:[OCMArg any]])
      .andDo(^(NSInvocation *invocation) {
        MSEventLog *log;
        [invocation getArgument:&log atIndex:2];
        type = log.type;
        name = log.name;
      });
  [MSMobileCenter configureWithAppSecret:kMSTestAppSecret];
  [[MSAnalytics sharedInstance] startWithLogManager:logManagerMock appSecret:kMSTestAppSecret];

  // When
  [MSAnalytics trackEvent:expectedName];

  // Then
  assertThat(type, is(kMSTypeEvent));
  assertThat(name, is(expectedName));
}

- (void)testTrackEventWithProperties {

  // If
  __block NSString *type;
  __block NSString *name;
  __block NSDictionary<NSString *, NSString *> *properties;
  NSString *expectedName = @"gotACoffee";
  NSDictionary *expectedProperties = @{ @"milk" : @"yes", @"cookie" : @"of course" };
  id<MSLogManager> logManagerMock = OCMProtocolMock(@protocol(MSLogManager));
  OCMStub([logManagerMock processLog:[OCMArg isKindOfClass:[MSLogWithProperties class]] forGroupId:[OCMArg any]])
      .andDo(^(NSInvocation *invocation) {
        MSEventLog *log;
        [invocation getArgument:&log atIndex:2];
        type = log.type;
        name = log.name;
        properties = log.properties;
      });
  [MSMobileCenter configureWithAppSecret:kMSTestAppSecret];
  [[MSAnalytics sharedInstance] startWithLogManager:logManagerMock appSecret:kMSTestAppSecret];

  // When
  [MSAnalytics trackEvent:expectedName withProperties:expectedProperties];

  // Then
  assertThat(type, is(kMSTypeEvent));
  assertThat(name, is(expectedName));
  assertThat(properties, is(expectedProperties));
}

- (void)testTrackPageWithoutProperties {

  // If
  __block NSString *name;
  __block NSString *type;
  NSString *expectedName = @"HomeSweetHome";
  id<MSLogManager> logManagerMock = OCMProtocolMock(@protocol(MSLogManager));
  OCMStub([logManagerMock processLog:[OCMArg isKindOfClass:[MSLogWithProperties class]] forGroupId:[OCMArg any]])
      .andDo(^(NSInvocation *invocation) {
        MSEventLog *log;
        [invocation getArgument:&log atIndex:2];
        type = log.type;
        name = log.name;
      });
  [MSMobileCenter configureWithAppSecret:kMSTestAppSecret];
  [[MSAnalytics sharedInstance] startWithLogManager:logManagerMock appSecret:kMSTestAppSecret];

  // When
  [MSAnalytics trackPage:expectedName];

  // Then
  assertThat(type, is(kMSTypePage));
  assertThat(name, is(expectedName));
}

- (void)testTrackPageWithProperties {

  // If
  __block NSString *type;
  __block NSString *name;
  __block NSDictionary<NSString *, NSString *> *properties;
  NSString *expectedName = @"HomeSweetHome";
  NSDictionary *expectedProperties = @{ @"Sofa" : @"yes", @"TV" : @"of course" };
  id<MSLogManager> logManagerMock = OCMProtocolMock(@protocol(MSLogManager));
  OCMStub([logManagerMock processLog:[OCMArg isKindOfClass:[MSLogWithProperties class]] forGroupId:[OCMArg any]])
      .andDo(^(NSInvocation *invocation) {
        MSEventLog *log;
        [invocation getArgument:&log atIndex:2];
        type = log.type;
        name = log.name;
        properties = log.properties;
      });
  [MSMobileCenter configureWithAppSecret:kMSTestAppSecret];
  [[MSAnalytics sharedInstance] startWithLogManager:logManagerMock appSecret:kMSTestAppSecret];

  // When
  [MSAnalytics trackPage:expectedName withProperties:expectedProperties];

  // Then
  assertThat(type, is(kMSTypePage));
  assertThat(name, is(expectedName));
  assertThat(properties, is(expectedProperties));
}

- (void)testAutoPageTracking {

  // For now auto page tracking is disabled by default
  XCTAssertFalse([MSAnalytics isAutoPageTrackingEnabled]);

  // When
  [MSAnalytics setAutoPageTrackingEnabled:YES];

  // Then
  XCTAssertTrue([MSAnalytics isAutoPageTrackingEnabled]);

  // When
  [MSAnalytics setAutoPageTrackingEnabled:NO];

  // Then
  XCTAssertFalse([MSAnalytics isAutoPageTrackingEnabled]);
}

- (void)testInitializationPriorityCorrect {
  XCTAssertTrue([[MSAnalytics sharedInstance] initializationPriority] == MSInitializationPriorityDefault);
}

- (void)testServiceNameIsCorrect {
  XCTAssertEqual([MSAnalytics serviceName], kMSAnalyticsServiceName);
}

@end
