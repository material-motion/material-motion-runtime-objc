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

#import "MDMPerforming.h"

@class MDMScheduler;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
/** The object provided to performers when they conform to MDMTransactionEmitting. */
@interface MDMTransactionEmitter : NSObject <MDMTransactionEmitting>

/** Initialize a newly created transaction emitter with the provided scheduler. */
- (nonnull instancetype)initWithScheduler:(nonnull MDMScheduler *)scheduler;

/** Use initWithScheduler: instead. */
- (nonnull instancetype)init NS_UNAVAILABLE;

@end
#pragma clang diagnostic pop
