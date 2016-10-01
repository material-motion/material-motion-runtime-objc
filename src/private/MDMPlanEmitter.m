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

#import "MDMPlanEmitter.h"

#import "MDMScheduler.h"

@interface MDMPlanEmitter ()

@property(nonatomic, weak) MDMScheduler *scheduler;
@property(nonatomic, weak) id target;

@end

@implementation MDMPlanEmitter

- (nonnull instancetype)initWithScheduler:(nonnull MDMScheduler *)scheduler target:(nonnull id)target {
  self = [super init];
  if (self) {
    self.scheduler = scheduler;
    self.target = target;
  }
  return self;
}

#pragma mark - MDMPlanEmitting

- (void)emitPlan:(NSObject<MDMPlan> *)plan {
  if (!self.scheduler || !self.target) {
    return;
  }
  [self.scheduler addPlan:plan toTarget:self.target];
}

@end
