/*
 Copyright 2016-present The Material Motion Authors. All Rights Reserved.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "MDMIsActiveTokenGenerator.h"

#import "MDMPerformerGroup.h"
#import "MDMPerformerInfo.h"

@interface MDMIsActiveTokenGenerator ()
@property(nonatomic, weak) MDMPerformerGroup *performerGroup;
@property(nonatomic, weak) MDMPerformerInfo *performerInfo;
@end

@interface MDMIsActiveToken : NSObject <MDMIsActiveTokenable>

- (nonnull instancetype)initWithPerformerGroup:(nonnull MDMPerformerGroup *)performerGroup
                                 performerInfo:(nonnull MDMPerformerInfo *)performerInfo
    NS_DESIGNATED_INITIALIZER;

- (nonnull instancetype)init NS_UNAVAILABLE;
+ (nonnull instancetype) new NS_UNAVAILABLE;

@property(nonatomic, weak) MDMPerformerGroup *performerGroup;
@property(nonatomic, weak) MDMPerformerInfo *performerInfo;
@property(nonatomic, assign, getter=isTerminated) BOOL terminated;

@end

@implementation MDMIsActiveToken

- (void)dealloc {
  if (!self.isTerminated) {
    [self terminate];
  }
}

- (instancetype)initWithPerformerGroup:(nonnull MDMPerformerGroup *)performerGroup
                         performerInfo:(nonnull MDMPerformerInfo *)performerInfo {
  self = [super init];
  if (self) {
    _performerGroup = performerGroup;
    _performerInfo = performerInfo;

    [self.performerGroup registerIsActiveToken:self withPerformerInfo:self.performerInfo];
  }
  return self;
}

- (void)terminate {
  NSAssert(!self.terminated, @"Is-active already terminated.");
  self.terminated = true;

  [self.performerGroup terminateIsActiveToken:self withPerformerInfo:self.performerInfo];
}

@end

@implementation MDMIsActiveTokenGenerator

- (nonnull instancetype)initWithPerformerGroup:(nonnull MDMPerformerGroup *)performerGroup
                                 performerInfo:(nonnull MDMPerformerInfo *)performerInfo {
  self = [super init];
  if (self) {
    _performerGroup = performerGroup;
    _performerInfo = performerInfo;
  }
  return self;
}

- (id<MDMIsActiveTokenable>)generate {
  if (!self.performerInfo.performer) {
    return nil;
  }
  return [[MDMIsActiveToken alloc] initWithPerformerGroup:self.performerGroup
                                            performerInfo:self.performerInfo];
}

@end
