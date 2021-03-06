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

#import "MDMMotionRuntime.h"
#import "MDMTargetRegistry.h"

@interface MDMPlanEmitter ()

@property(nonatomic, weak) MDMTargetRegistry *targetRegistry;
@property(nonatomic, weak) id target;

@end

@implementation MDMPlanEmitter

- (instancetype)initWithTargetRegistry:(MDMTargetRegistry *)targetRegistry target:(id)target {
  self = [super init];
  if (self) {
    self.targetRegistry = targetRegistry;
    self.target = target;
  }
  return self;
}

#pragma mark - MDMPlanEmitting

- (void)emitPlan:(NSObject<MDMPlan> *)plan {
  MDMTargetRegistry *registry = self.targetRegistry;
  id target = self.target;
  if (!registry || !target) {
    return;
  }
  [registry.runtime addPlan:plan to:target];
}

@end
