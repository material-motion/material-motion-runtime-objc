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

import UIKit
import MaterialMotionRuntime

// This example demonstrates how to use composition to create a complex interaction composed of
// many plans. Building off of our draggable examples, we'll be making the view in this example
// tossable. The user can drag anywhere on the screen to grab the square. The square can then be
// tossed in any direction and it will spring back to the center of the screen.
class LifeOfAComposablePlanExampleController: UIViewController {
  let scheduler = Scheduler()

  func commonInit() {
    title = "Touch anywhere to toss the square"
  }

  // MARK: Configuring views and interactions

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = .white

    let square = UIView(frame: CGRect(x: 100, y: 100, width: 100, height: 100))
    square.backgroundColor = .red
    view.addSubview(square)

    let pan = UIPanGestureRecognizer()
    view.addGestureRecognizer(pan)

    // Notice that our view controller is only concerned with one plan: Tossable. This plan's
    // performer will coordinate the emission of plans in reaction to the gesture recognizer's
    // events.
    scheduler.addPlan(Tossable(gestureRecognizer: pan), to: square)
  }

  // MARK: Routing initializers

  override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

    commonInit()
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)

    commonInit()
  }
}

// MARK: - Composite plans

// Enables the target to be dragged and, upon release, to be tossed to the midpoint of the target's
// parent view using UIDynamics.
private class Tossable: NSObject, Plan {
  let gestureRecognizer: UIPanGestureRecognizer
  required init(gestureRecognizer: UIPanGestureRecognizer) {
    self.gestureRecognizer = gestureRecognizer
    super.init()
  }

  func performerClass() -> AnyClass {
    return Performer.self
  }

  func copy(with zone: NSZone? = nil) -> Any {
    return Tossable(gestureRecognizer: gestureRecognizer)
  }

  private class Performer: NSObject, PlanPerforming, ComposablePerforming {
    let target: UIView
    required init(target: Any) {
      self.target = target as! UIView
      super.init()
    }

    func addPlan(_ plan: Plan) {
      let tossable = plan as! Tossable

      // Draggable is being reused from the Life of a Configurable Plan example.
      emitter.emitPlan(Draggable(panGestureRecognizer: tossable.gestureRecognizer))

      tossable.gestureRecognizer.addTarget(self, action: #selector(didPan(gesture:)))
    }

    func didPan(gesture: UIPanGestureRecognizer) {
      switch gesture.state {
      case .began:
        emitter.emitPlan(Grabbed())

      case .ended: fallthrough
      case .cancelled:
        let midpoint = CGPoint(x: target.superview!.bounds.midX,
                               y: target.superview!.bounds.midY)
        emitter.emitPlan(Anchored(to: midpoint))
        emitter.emitPlan(Impulse(velocity: gesture.velocity(in: target)))

      default: ()
      }
    }

    var emitter: PlanEmitting!
    func setPlanEmitter(_ planEmitter: PlanEmitting) {
      emitter = planEmitter
    }
  }
}

// MARK: - UIDynamics plans

// Anchors the target to a given position using UIDynamics.
private class Anchored: NSObject {
  let position: CGPoint
  init(to position: CGPoint) {
    self.position = position
    super.init()
  }
}

// Applies an instantaneous impulse to the target using UIDynamics.
private class Impulse: NSObject {
  let velocity: CGPoint
  init(velocity: CGPoint) {
    self.velocity = velocity
    super.init()
  }
}

// Removes all active UIDynamics behaviors associated with the target.
private class Grabbed: NSObject {}

private class UIDynamicsPerformer: NSObject, PlanPerforming {
  let target: UIView
  let dynamicAnimator: UIDynamicAnimator
  required init(target: Any) {
    self.target = target as! UIView
    dynamicAnimator = UIDynamicAnimator(referenceView: self.target.superview!)
    super.init()
  }

  var snapBehavior: UISnapBehavior?
  func addPlan(_ plan: Plan) {
    switch plan {
    case let anchoredTo as Anchored:
      if let behavior = snapBehavior {
        dynamicAnimator.removeBehavior(behavior)
      }
      snapBehavior = UISnapBehavior(item: target, snapTo: anchoredTo.position)
      dynamicAnimator.addBehavior(snapBehavior!)

    case let impulse as Impulse:
      let push = UIPushBehavior(items: [target], mode: .instantaneous)
      let velocity = impulse.velocity

      let direction = CGVector(dx: velocity.x / 100, dy: velocity.y / 100)
      push.pushDirection = direction
      dynamicAnimator.addBehavior(push)

    case is Grabbed:
      dynamicAnimator.removeAllBehaviors()
      snapBehavior = nil

    default:
      assert(false)
    }
  }
}

// MARK: Plan conformity

// Note that we're using extensions to implement Plan conformity in this example so that the code
// above can focus on the novel bits.

extension Anchored: Plan {
  func performerClass() -> AnyClass {
    return UIDynamicsPerformer.self
  }

  func copy(with zone: NSZone? = nil) -> Any {
    return Anchored(to: position)
  }
}

extension Grabbed: Plan {
  func performerClass() -> AnyClass {
    return UIDynamicsPerformer.self
  }

  func copy(with zone: NSZone? = nil) -> Any {
    return Grabbed()
  }
}

extension Impulse: Plan {
  func performerClass() -> AnyClass {
    return UIDynamicsPerformer.self
  }

  func copy(with zone: NSZone? = nil) -> Any {
    return Impulse(velocity: velocity)
  }
}

private func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
  return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}
