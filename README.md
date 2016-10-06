# Material Motion Runtime for Apple Devices

[![Build Status](https://travis-ci.org/material-motion/material-motion-runtime-objc.svg?branch=develop)](https://travis-ci.org/material-motion/material-motion-runtime-objc)
[![codecov](https://codecov.io/gh/material-motion/material-motion-runtime-objc/branch/develop/graph/badge.svg)](https://codecov.io/gh/material-motion/material-motion-runtime-objc)

The Material Motion Runtime is a tool for describing motion declaratively.

## Declarative motion: motion as data

This library does not do much on its own. What it does do, however, is enable the expression of
motion as discrete units of data that can be introspected, composed, and sent over a wire.

This library encourages you to describe motion as data, or what we call *plans*. Plans are committed
to a *scheduler*. A scheduler coordinates the creation of *performers*, objects responsible for
translating plans into concrete execution.

## Installation

### Installation with CocoaPods

> CocoaPods is a dependency manager for Objective-C and Swift libraries. CocoaPods automates the
> process of using third-party libraries in your projects. See
> [the Getting Started guide](https://guides.cocoapods.org/using/getting-started.html) for more
> information. You can install it with the following command:
>
>     gem install cocoapods

Add `MaterialMotionRuntime` to your `Podfile`:

    pod 'MaterialMotionRuntime'

Then run the following command:

    pod install

### Usage

Import the Material Motion Runtime framework:

    @import MaterialMotionRuntime;

You will now have access to all of the APIs.

## Example apps/unit tests

Check out a local copy of the repo to access the Catalog application by running the following
commands:

    git clone https://github.com/material-motion/material-motion-runtime-objc.git
    cd material-motion-runtime-objc
    pod install
    open MaterialMotionRuntime.xcworkspace

## Guides

1. [Architecture](#architecture)
2. [How to define a new plan and performer type](#how-to-create-a-new-plan-and-performer-type)
3. [How to commit a plan to a scheduler](#how-to-commit-a-plan-to-a-scheduler)
4. [How to configure performers with plans](#how-to-configure-performers-with-plans)
5. [How to use composition to fulfill plans](#how-to-use-composition-to-fulfill-plans)
6. [How to indicate continuous performance](#how-to-indicate-continuous-performance)
7. [How to trace internal scheduler events](#how-to-trace-internal-scheduler-events)

### Architecture

The Material Motion Runtime consists of two groups of APIs: a scheduler/transaction object and a
constellation of protocols loosely consisting of plan and performing types.

#### Scheduler

The [Scheduler](https://material-motion.github.io/material-motion-runtime-objc/Classes/MDMScheduler.html)
object is a coordinating entity whose primary responsibility is to fulfill plans by creating
performers. You can create many schedulers throughout the lifetime of your application. A good rule
of thumb is to have one scheduler per interaction or transition.

#### Plan + Performing types

The [Plan](https://material-motion.github.io/material-motion-runtime-objc/Protocols/MDMPlan.html)
and [Performing](https://material-motion.github.io/material-motion-runtime-objc/Protocols/MDMPerforming.html)
protocol each define the minimal characteristics required for an object to be considered either a
plan or a performer, respectively, by the Material Motion Runtime.

Plans and performers have a symbiotic relationship. A plan is executed by the performer it defines.
Performer behavior is configured by the provided plan instances.

Learn more about the Material Motion Runtime by reading the
[Starmap](https://material-motion.gitbooks.io/material-motion-starmap/content/specifications/runtime/).

### How to create a new plan and performer type

The following steps provide copy-pastable snippets of code.

#### Step 1: Define the plan type

Questions to ask yourself when creating a new plan type:

- What do I want my plan/performer to accomplish?
- Will my performer need many plans to achieve the desired outcome?
- How can I name my plan such that it clearly communicates either a **behavior** or a
  **change in state**?

As general rules:

1. Plans with an *-able* suffix alter the **behavior** of the target, often indefinitely. Examples:
   Draggable, Pinchable, Tossable.
2. Plans that are *verbs* describe some **change in state**, often over a period of time. Examples:
   FadeIn, Tween, SpringTo.

Code snippets:

***In Objective-C:***

```objc
@interface <#Plan#> : NSObject
@end

@implementation <#Plan#>
@end
```

***In Swift:***

```swift
class <#Plan#>: NSObject {
}
```

#### Step 2: Define the performer type

Performers are responsible for fulfilling plans. Fulfillment is possible in a variety of ways:

- [PlanPerforming](https://material-motion.github.io/material-motion-runtime-objc/Protocols/MDMPlanPerforming.html): [How to configure performers with plans](#how-to-configure-performers-with-plans)
- [DelegatedPerforming](https://material-motion.github.io/material-motion-runtime-objc/Protocols/MDMDelegatedPerforming.html)
- [ComposablePerforming](https://material-motion.github.io/material-motion-runtime-objc/Protocols/MDMComposablePerforming.html): [How to use composition to fulfill plans](#how-to-use-composition-to-fulfill-plans)

See the associated links for more details on each performing type.

> Note: only one instance of a type of performer **per target** is ever created. This allows you to
> register multiple plans to the same target in order to configure a performer. See
> [How to configure performers with plans](#how-to-configure-performers-with-plans) for more details.

Code snippets:

***In Objective-C:***

```objc
@interface <#Performer#> : NSObject <MDMPerforming>
@end

@implementation <#Performer#> {
  UIView *_target;
}

- (instancetype)initWithTarget:(id)target {
  self = [super init];
  if (self) {
    assert([target isKindOfClass:[UIView class]]);
    _target = target;
  }
  return self;
}

@end
```

***In Swift:***

```swift
class <#Performer#>: NSObject, Performing {
  let target: UIView
  required init(target: Any) {
    self.target = target as! UIView
    super.init()
  }
}
```

#### Step 3: Make the plan type a formal Plan

Conforming to Plan requires:

1. that you define the type of performer your plan requires, and
2. that your plan be copyable.

Code snippets:

***In Objective-C:***

```objc
@interface <#Plan#> : NSObject <MDMPlan>
@end

@implementation <#Plan#>

- (Class)performerClass {
  return [<#Plan#> class];
}

- (id)copyWithZone:(NSZone *)zone {
  return [[[self class] allocWithZone:zone] init];
}

@end
```

***In Swift:***

```swift
class <#Plan#>: NSObject, Plan {
  func performerClass() -> AnyClass {
    return <#Performer#>.self
  }
  func copy(with zone: NSZone? = nil) -> Any {
    return <#Plan#>()
  }
}
```

### How to commit a plan to a scheduler

#### Step 1: Create and store a reference to a scheduler instance

Code snippets:

***In Objective-C:***

```objc
@interface MyClass ()
@property(nonatomic, strong) MDMScheduler* scheduler;
@end

- (instancetype)init... {
  ...
  self.scheduler = [MDMScheduler new];
  ...
}
```

***In Swift:***

```swift
class MyClass {
  let scheduler = Scheduler()
}
```

#### Step 2: Associate plans with targets

Code snippets:

***In Objective-C:***

```objc
[scheduler addPlan:<#Plan instance#> to:<#View instance#>];
```

***In Swift:***

```swift
scheduler.addPlan(<#Plan instance#>, to:<#View instance#>)
```

### How to configure performers with plans

Configuring performers with plans starts by making your performer conform to
[PlanPerforming](https://material-motion.github.io/material-motion-runtime-objc/Protocols/MDMPlanPerforming.html).

PlanPerforming requires that you implement the `addPlan:` method. This method will only be invoked
with plans that require use of this performer.

Code snippets:

***In Objective-C:***

```objc
@interface <#Performer#> (PlanPerforming) <MDMPlanPerforming>
@end

@implementation <#Performer#> (PlanPerforming)

- (void)addPlan:(id<MDMPlan>)plan {
  <#Plan#>* <#casted plan instance#> = plan;

  // Do something with the plan.
}

@end
```

***In Swift:***

```swift
extension <#Performer#>: PlanPerforming {
  func add(plan: Plan) {
    let <#casted plan instance#> = plan as! <#Plan#>

    // Do something with the plan.
  }
}
```

***Handling multiple plan types in Swift:***

Make use of Swift's typed switch/casing to handle multiple plan types.

```swift
func add(plan: Plan) {
  switch plan {
  case let <#plan instance 1#> as <#Plan type 1#>:
    ()

  case let <#plan instance 2#> as <#Plan type 2#>:
    ()

  case is <#Plan type 3#>:
    ()

  default:
    assert(false)
  }
}
```

### How to use composition to fulfill plans

A composition performer is able to emit new plans using a plan emitter. This feature enables the
reuse of plans and the creation of higher-order abstractions.

#### Step 1: Conform to ComposablePerforming and store the plan emitter

Code snippets:

***In Objective-C:***

```objc
@interface <#Performer#> ()
@property(nonatomic, strong) id<MDMPlanEmitting> planEmitter;
@end

@interface <#Performer#> (Composition) <MDMComposablePerforming>
@end

@implementation <#Performer#> (Composition)

- (void)setPlanEmitter:(id<MDMPlanEmitting>)planEmitter {
  self.planEmitter = planEmitter;
}

@end
```

***In Swift:***

```swift
// Store the emitter in your class' definition.
class <#Performer#>: ... {
  ...
  var emitter: PlanEmitting!
  ...
}

extension <#Performer#>: ComposablePerforming {
  var emitter: PlanEmitting!
  func setPlanEmitter(_ planEmitter: PlanEmitting) {
    emitter = planEmitter
  }
}
```

#### Step 2: Emit plans

Performers are only able to emit plans for their associated target.

Code snippets:

***In Objective-C:***

```objc
[self.planEmitter emitPlan:<#(nonnull id<MDMPlan>)#>];
```

***In Swift:***

```swift
emitter.emitPlan<#T##Plan#>)
```

### How to indicate continuous performance

Oftentimes performers will perform their actions over a period of time or while an interaction is
active. These types of performers are called continuous performers.

A continuous performer is able to affect the active state of the scheduler by generating is-active
tokens. The scheduler is considered active so long as an is-active token exists and has not been
terminated. Continuous performers are expected to terminate a token when its corresponding work has
completed.

For example, a performer that registers a platform animation might generate a token when the
animation starts. When the animation completes the token would be terminated.

#### Step 1: Conform to ContinuousPerforming and store the token generator

Code snippets:

***In Objective-C:***

```objc
@interface <#Performer#> ()
@property(nonatomic, strong) id<MDMIsActiveTokenGenerating> tokenGenerator;
@end

@interface <#Performer#> (Composition) <MDMComposablePerforming>
@end

@implementation <#Performer#> (Composition)

- (void)setIsActiveTokenGenerator:(id<MDMIsActiveTokenGenerating>)isActiveTokenGenerator {
  self.tokenGenerator = isActiveTokenGenerator;
}

@end
```

***In Swift:***

```swift
// Store the emitter in your class' definition.
class <#Performer#>: ... {
  ...
  var tokenGenerator: IsActiveTokenGenerating!
  ...
}

extension <#Performer#>: ContinuousPerforming {
  func set(isActiveTokenGenerator: IsActiveTokenGenerating) {
    tokenGenerator = isActiveTokenGenerator
  }
}
```

#### Step 2: Generate a token when some continuous work has started

You will likely need to store the token in order to be able to reference it at a later point.

Code snippets:

***In Objective-C:***

```objc
id<MDMIsActiveTokenable> token = [self.tokenGenerator generate];
tokenMap[animation] = token;
```

***In Swift:***

```swift
let token = tokenGenerator.generate()!
tokenMap[animation] = token
```

#### Step 3: Terminate the token when work has completed

Code snippets:

***In Objective-C:***

```objc
[token terminate];
```

***In Swift:***

```swift
token.terminate()
```

### How to trace internal scheduler events

Tracing allows you to observe internal events occuring within a scheduler. This information may be
used for the following purposes:

- Debug logging.
- Inspection tooling.

Use for other purposes is unsupported.

#### Step 1: Create a tracer class

Code snippets:

***In Objective-C:***

```objc
@interface <#Custom tracer#> : NSObject <MDMTracing>
@end

@implementation <#Custom tracer#>
@end
```

***In Swift:***

```swift
class <#Custom tracer#>: NSObject, Tracing {
}
```

#### Step 2: Implement methods

The documentation for the Tracing protocol enumerates the available methods.

Code snippets:

***In Objective-C:***

```objc
@implementation <#Custom tracer#>

- (void)didAddPlan:(id<MDMPlan>)plan to:(id)target {

}

@end
```

***In Swift:***

```swift
class <#Custom tracer#>: NSObject, Tracing {
  func didAddPlan(_ plan: Plan, to target: Any) {

  }
}
```

## Contributing

We welcome contributions!

Check out our [upcoming milestones](https://github.com/material-motion/material-motion-runtime-objc/milestones).

Learn more about [our team](https://material-motion.gitbooks.io/material-motion-team/content/),
[our community](https://material-motion.gitbooks.io/material-motion-team/content/community/), and
our [contributor essentials](https://material-motion.gitbooks.io/material-motion-team/content/essentials/).

## License

Licensed under the Apache 2.0 license. See LICENSE for details.

