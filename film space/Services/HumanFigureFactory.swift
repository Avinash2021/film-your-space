//
//  HumanFigureFactory.swift
//  film space
//

import RealityKit
import UIKit

enum HumanFigureFactory {
    private static let skinColor = UIColor(red: 0.76, green: 0.60, blue: 0.42, alpha: 1)
    private static let clothingColor = UIColor(red: 0.35, green: 0.38, blue: 0.45, alpha: 1)

    // Standing baseline layout (meters), feet flat on the floor at y = 0.
    // Proportions follow the classic ~8-heads-tall figure-drawing canon (head
    // unit ≈ 0.22 m for this figure's scale): upper arm ≈ 1.5 head units,
    // forearm ≈ 1.3, thigh/shin ≈ 2 each — rather than the old arbitrary
    // block lengths, which read as noticeably long/gangly.
    private static let headRadius: Float = 0.11
    private static let headYLocal: Float = 0.72 // relative to the pelvis/torso pivot
    private static let torsoHeight: Float = 0.50
    private static let torsoRadius: Float = 0.15
    private static let torsoYLocal: Float = 0.32
    private static let upperArmLength: Float = 0.33
    private static let upperArmRadius: Float = 0.055
    private static let forearmLength: Float = 0.29
    private static let forearmRadius: Float = 0.045
    private static let shoulderX: Float = 0.22
    private static let shoulderYLocal: Float = 0.38
    private static let shoulderJointRadius: Float = 0.065
    private static let elbowJointRadius: Float = 0.05
    fileprivate static let idleShoulderSplay: Float = 0.35
    fileprivate static let idleElbowSplay: Float = 0.15

    private static let hipX: Float = 0.11
    private static let hipHeightStanding: Float = 0.90
    private static let thighLength: Float = 0.44
    private static let thighRadius: Float = 0.09
    private static let shinLength: Float = 0.42
    private static let shinRadius: Float = 0.07
    private static let hipJointRadius: Float = 0.10
    private static let kneeJointRadius: Float = 0.085
    private static let ankleJointRadius: Float = 0.06
    private static let footSize: SIMD3<Float> = [0.14, 0.08, 0.24]
    private static let footOffset: SIMD3<Float> = [0, -0.04, 0.02]

    /// Gap between the top of the head and the floating name card.
    static let nameTagOffsetAboveHead: Float = headRadius + 0.22

    /// Rotation applied to the whole figure root for poses that recline it onto its back.
    static func rootTilt(for pose: CharacterPose) -> simd_quatf {
        pose == .lying ? simd_quatf(angle: -.pi / 2, axis: [1, 0, 0]) : simd_quatf()
    }

    /// Extra vertical lift stacked on top of floor-grounding, for poses that should look airborne.
    static func extraLift(for pose: CharacterPose) -> Float {
        pose == .sprint ? 0.05 : 0
    }

    /// The head's position in the figure's own local space (before the root-level
    /// tilt/yaw applied for lying and rotation are added). Used to keep the floating
    /// name card locked above the head in every pose, including reclined ones.
    static func headLocalPosition(for pose: CharacterPose) -> SIMD3<Float> {
        let rig = PoseRig.make(for: pose)
        let torsoOrientation = simd_quatf(angle: rig.torsoRoll, axis: [0, 0, 1])
            * simd_quatf(angle: rig.torsoPitch, axis: [1, 0, 0])
        let torsoPosition = SIMD3<Float>(0, rig.pelvisHeight, rig.torsoOffsetZ)
        return torsoPosition + torsoOrientation.act(SIMD3<Float>(0, headYLocal, 0))
    }

    static func makeHumanFigure(isSelected: Bool, pose: CharacterPose) -> Entity {
        let root = Entity()
        root.name = "HumanFigure"

        let skin = SimpleMaterial(color: skinColor, roughness: 0.6, isMetallic: false)
        let clothing = SimpleMaterial(
            color: isSelected ? UIColor.systemBlue : clothingColor,
            roughness: 0.5,
            isMetallic: false
        )

        let rig = PoseRig.make(for: pose)

        let torsoPivot = Entity()
        torsoPivot.name = "TorsoPivot"
        torsoPivot.position = [0, rig.pelvisHeight, rig.torsoOffsetZ]
        torsoPivot.orientation = simd_quatf(angle: rig.torsoRoll, axis: [0, 0, 1])
            * simd_quatf(angle: rig.torsoPitch, axis: [1, 0, 0])
        root.addChild(torsoPivot)

        let head = ModelEntity(mesh: .generateSphere(radius: headRadius), materials: [skin])
        head.name = "Head"
        head.position = [0, headYLocal, 0]
        torsoPivot.addChild(head)

        let torso = ModelEntity(mesh: .generateCylinder(height: torsoHeight, radius: torsoRadius), materials: [clothing])
        torso.position = [0, torsoYLocal, 0]
        torsoPivot.addChild(torso)

        addArm(to: torsoPivot, side: -1, clothing: clothing, skin: skin, arm: rig.leftArm)
        addArm(to: torsoPivot, side: 1, clothing: clothing, skin: skin, arm: rig.rightArm)

        addLeg(to: root, side: -1, clothing: clothing, skin: skin, leg: rig.leftLeg)
        addLeg(to: root, side: 1, clothing: clothing, skin: skin, leg: rig.rightLeg)

        let bounds = root.visualBounds(relativeTo: nil)
        let size = SIMD3<Float>(
            max(bounds.max.x - bounds.min.x, 0.3),
            max(bounds.max.y - bounds.min.y, 0.05),
            max(bounds.max.z - bounds.min.z, 0.3)
        )
        let center = SIMD3<Float>(
            (bounds.max.x + bounds.min.x) / 2,
            (bounds.max.y + bounds.min.y) / 2,
            (bounds.max.z + bounds.min.z) / 2
        )
        root.components.set(CollisionComponent(shapes: [.generateBox(size: size).offsetBy(translation: center)]))
        root.components.set(InputTargetComponent())

        return root
    }

    // Ball joints at the shoulder and elbow (a classic articulated-mannequin
    // touch) always fully cover the seam between the two rotating cylinders,
    // whatever angle they're bent to — unlike the old boxes, which visibly
    // gapped or intersected at extreme joint rotations.
    private static func addArm(
        to torsoPivot: Entity,
        side: Float,
        clothing: SimpleMaterial,
        skin: SimpleMaterial,
        arm: ArmRig
    ) {
        let shoulder = Entity()
        shoulder.position = [side * shoulderX, shoulderYLocal, 0]
        shoulder.orientation = simd_quatf(angle: side * arm.shoulderSplay, axis: [0, 0, 1])
            * simd_quatf(angle: arm.shoulderForward, axis: [1, 0, 0])
        torsoPivot.addChild(shoulder)

        let shoulderBall = ModelEntity(mesh: .generateSphere(radius: shoulderJointRadius), materials: [clothing])
        shoulder.addChild(shoulderBall)

        let upperArm = ModelEntity(
            mesh: .generateCylinder(height: upperArmLength, radius: upperArmRadius),
            materials: [clothing]
        )
        upperArm.position = [0, -upperArmLength / 2, 0]
        shoulder.addChild(upperArm)

        let elbow = Entity()
        elbow.position = [0, -upperArmLength, 0]
        elbow.orientation = simd_quatf(angle: side * arm.elbowSplay, axis: [0, 0, 1])
            * simd_quatf(angle: arm.elbow, axis: [1, 0, 0])
        shoulder.addChild(elbow)

        let elbowBall = ModelEntity(mesh: .generateSphere(radius: elbowJointRadius), materials: [skin])
        elbow.addChild(elbowBall)

        let forearm = ModelEntity(
            mesh: .generateCylinder(height: forearmLength, radius: forearmRadius),
            materials: [skin]
        )
        forearm.position = [0, -forearmLength / 2, 0]
        elbow.addChild(forearm)
    }

    // Ball joints at the hip, knee, and ankle cover the seam between rotating
    // cylinders at any bend angle, so toggling between standing/sitting/kneeling
    // deforms cleanly with no gap or clipping at the pivots.
    private static func addLeg(
        to root: Entity,
        side: Float,
        clothing: SimpleMaterial,
        skin: SimpleMaterial,
        leg: LegRig
    ) {
        let hip = Entity()
        hip.position = [side * hipX, hipHeightStanding, leg.hipOffsetZ]
        hip.orientation = simd_quatf(angle: leg.hip, axis: [1, 0, 0])
        root.addChild(hip)

        let hipBall = ModelEntity(mesh: .generateSphere(radius: hipJointRadius), materials: [clothing])
        hip.addChild(hipBall)

        let thigh = ModelEntity(
            mesh: .generateCylinder(height: thighLength, radius: thighRadius),
            materials: [clothing]
        )
        thigh.position = [0, -thighLength / 2, 0]
        hip.addChild(thigh)

        let knee = Entity()
        knee.position = [0, -thighLength, 0]
        knee.orientation = simd_quatf(angle: leg.knee, axis: [1, 0, 0])
        hip.addChild(knee)

        let kneeBall = ModelEntity(mesh: .generateSphere(radius: kneeJointRadius), materials: [clothing])
        knee.addChild(kneeBall)

        let shin = ModelEntity(
            mesh: .generateCylinder(height: shinLength, radius: shinRadius),
            materials: [clothing]
        )
        shin.position = [0, -shinLength / 2, 0]
        knee.addChild(shin)

        let ankle = Entity()
        ankle.position = [0, -shinLength, 0]
        ankle.orientation = simd_quatf(angle: leg.ankle, axis: [1, 0, 0])
        knee.addChild(ankle)

        let ankleBall = ModelEntity(mesh: .generateSphere(radius: ankleJointRadius), materials: [skin])
        ankle.addChild(ankleBall)

        let foot = ModelEntity(mesh: .generateBox(size: footSize), materials: [skin])
        foot.position = footOffset
        ankle.addChild(foot)
    }
}

private struct LegRig {
    var hipOffsetZ: Float = 0
    var hip: Float = 0
    var knee: Float = 0
    var ankle: Float = 0
}

private struct ArmRig {
    var shoulderForward: Float = 0
    var shoulderSplay: Float = HumanFigureFactory.idleShoulderSplay
    var elbow: Float = 0
    var elbowSplay: Float = HumanFigureFactory.idleElbowSplay
}

private struct PoseRig {
    var pelvisHeight: Float
    var torsoOffsetZ: Float = 0
    var torsoPitch: Float = 0
    var torsoRoll: Float = 0
    var leftLeg = LegRig()
    var rightLeg = LegRig()
    var leftArm = ArmRig()
    var rightArm = ArmRig()

    private static let deg = Float.pi / 180

    static func make(for pose: CharacterPose) -> PoseRig {
        switch pose {
        case .standing:
            return PoseRig(pelvisHeight: 0.90)

        case .sitting:
            // Hip forward 90° so the thigh is horizontal; knee back 90° so the
            // shin hangs straight down again and the feet stay flat.
            let leg = LegRig(hip: -90 * deg, knee: 90 * deg, ankle: 0)
            return PoseRig(pelvisHeight: 0.46, leftLeg: leg, rightLeg: leg)

        case .kneeling:
            // Knee folds back ~105°; ankle folds the remaining ~75° (105+75=180)
            // so the foot ends up flat, top-down, along the floor.
            let kneeAngle: Float = 105 * deg
            let leg = LegRig(hip: 0, knee: kneeAngle, ankle: 180 * deg - kneeAngle)
            return PoseRig(pelvisHeight: 0.44, leftLeg: leg, rightLeg: leg)

        case .lying:
            // The root tilt (see rootTilt(for:)) does the actual reclining;
            // arms relax straight at the sides with no idle splay.
            let arm = ArmRig(shoulderForward: 0, shoulderSplay: 0, elbow: 0, elbowSplay: 0)
            return PoseRig(pelvisHeight: 0.90, leftArm: arm, rightArm: arm)

        case .crouch:
            // Knees bend ~45°, hips hinge forward the same amount so the
            // shin cancels back to vertical (feet stay planted), while the
            // torso hinges forward hard for a tactical sneak silhouette.
            let leg = LegRig(hip: -45 * deg, knee: 45 * deg, ankle: 0)
            return PoseRig(pelvisHeight: 0.77, torsoPitch: 35 * deg, leftLeg: leg, rightLeg: leg)

        case .lean:
            // Torso shifts back and tilts back 8°; legs angle forward from the
            // hip (heels extend past the torso's vertical line) with the
            // ankle compensating so the feet stay flat on the floor.
            let leg = LegRig(hip: -12 * deg, knee: 0, ankle: 12 * deg)
            return PoseRig(
                pelvisHeight: 0.88,
                torsoOffsetZ: -0.12,
                torsoPitch: -8 * deg,
                leftLeg: leg,
                rightLeg: leg
            )

        case .fall:
            // Legs collapse into a loose heap; the torso tips back and rolls
            // to one side. Arms are asymmetric and loose (no idle splay match
            // on both sides) to read as limp rather than posed.
            let leg = LegRig(hip: -65 * deg, knee: 110 * deg, ankle: 0)
            let leftArm = ArmRig(shoulderForward: -20 * deg, shoulderSplay: 0.5, elbow: -30 * deg, elbowSplay: 0.2)
            let rightArm = ArmRig(shoulderForward: 10 * deg, shoulderSplay: 0.15, elbow: -60 * deg, elbowSplay: 0.4)
            return PoseRig(
                pelvisHeight: 0.35,
                torsoPitch: -45 * deg,
                torsoRoll: 30 * deg,
                leftLeg: leg,
                rightLeg: leg,
                leftArm: leftArm,
                rightArm: rightArm
            )

        case .stance:
            // Feet staggered front/back with knees bent slightly for a stable
            // athletic base; both arms raised in a defensive guard.
            let front = LegRig(hipOffsetZ: 0.18, hip: -10 * deg, knee: 20 * deg, ankle: -10 * deg)
            let back = LegRig(hipOffsetZ: -0.18, hip: 8 * deg, knee: 15 * deg, ankle: -23 * deg)
            let guardArm = ArmRig(shoulderForward: -40 * deg, shoulderSplay: 0.1, elbow: -95 * deg, elbowSplay: 0)
            return PoseRig(pelvisHeight: 0.80, leftLeg: front, rightLeg: back, leftArm: guardArm, rightArm: guardArm)

        case .sprint:
            // Torso pitches forward hard; front leg drives up and forward,
            // back leg trails fully extended; opposite arm pumps forward.
            let front = LegRig(hipOffsetZ: 0.30, hip: -55 * deg, knee: 70 * deg, ankle: -15 * deg)
            let back = LegRig(hipOffsetZ: -0.30, hip: 35 * deg, knee: 0, ankle: 20 * deg)
            let frontSideArmBack = ArmRig(shoulderForward: 35 * deg, shoulderSplay: 0, elbow: -60 * deg, elbowSplay: 0)
            let oppositeArmForward = ArmRig(shoulderForward: -50 * deg, shoulderSplay: 0, elbow: -100 * deg, elbowSplay: 0)
            return PoseRig(
                pelvisHeight: 0.90,
                torsoPitch: 25 * deg,
                leftLeg: front,
                rightLeg: back,
                leftArm: frontSideArmBack,
                rightArm: oppositeArmForward
            )

        case .walk:
            // Subtle forward lean; grounded split-stride with the front heel
            // down and the back foot on the ball. Arms swing in opposition:
            // right leg forward pairs with left arm forward.
            let front = LegRig(hipOffsetZ: 0.20, hip: -20 * deg, knee: 10 * deg, ankle: -15 * deg)
            let back = LegRig(hipOffsetZ: -0.20, hip: 15 * deg, knee: 5 * deg, ankle: 20 * deg)
            let armForward = ArmRig(shoulderForward: -25 * deg, shoulderSplay: 0.15, elbow: -20 * deg, elbowSplay: 0.1)
            let armBack = ArmRig(shoulderForward: 20 * deg, shoulderSplay: 0.15, elbow: -15 * deg, elbowSplay: 0.1)
            return PoseRig(
                pelvisHeight: 0.88,
                torsoPitch: 5 * deg,
                leftLeg: back,
                rightLeg: front,
                leftArm: armForward,
                rightArm: armBack
            )
        }
    }
}
