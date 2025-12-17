//
//  HVJointOfFinger.swift
//  HappyBeam
//
//  Ported from HandVector
//

import ARKit


public enum HVJointOfFinger:Sendable, Equatable, CaseIterable {
    case thumb
    case indexFinger
    case middleFinger
    case ringFinger
    case littleFinger
    case metacarpal
    case forearm
    
    public var jointGroupNames: [HandSkeleton.JointName] {
        switch self {
        case .thumb:
            [.thumbKnuckle, .thumbIntermediateBase, .thumbIntermediateTip, .thumbTip]
        case .indexFinger:
            [.indexFingerKnuckle, .indexFingerIntermediateBase, .indexFingerIntermediateTip, .indexFingerTip]
        case .middleFinger:
            [.middleFingerKnuckle, .middleFingerIntermediateBase, .middleFingerIntermediateTip, .middleFingerTip]
        case .ringFinger:
            [.ringFingerKnuckle, .ringFingerIntermediateBase, .ringFingerIntermediateTip, .ringFingerTip]
        case .littleFinger:
            [.littleFingerKnuckle, .littleFingerIntermediateBase, .littleFingerIntermediateTip, .littleFingerTip]
        case .metacarpal:
            [.indexFingerMetacarpal, .middleFingerMetacarpal, .ringFingerMetacarpal, .littleFingerMetacarpal]
        case .forearm:
            [.forearmWrist, .forearmArm]
        }
    }
    
    public var fingerShapeConfiguration: FingerShapeConfiguration {
        switch self {
        case .thumb:
            return FingerShapeConfiguration(minimumBaseCurlDegrees: 0, maximumBaseCurlDegrees: 60, minimumTipCurlDegrees1: 0, maximumTipCurlDegrees1: 80, minimumSpreadDegrees: 10, maximumSpreadDegrees: 45)
        case .indexFinger:
            return FingerShapeConfiguration(minimumBaseCurlDegrees: -10, maximumBaseCurlDegrees: 90, minimumTipCurlDegrees1: 0, maximumTipCurlDegrees1: 100, minimumSpreadDegrees: 0, maximumSpreadDegrees: 20)
        case .middleFinger:
            return FingerShapeConfiguration(minimumBaseCurlDegrees: -10, maximumBaseCurlDegrees: 90, minimumTipCurlDegrees1: 0, maximumTipCurlDegrees1: 100, minimumSpreadDegrees: 0, maximumSpreadDegrees: 10)
        case .ringFinger:
            return FingerShapeConfiguration(minimumBaseCurlDegrees: -10, maximumBaseCurlDegrees: 90, minimumTipCurlDegrees1: 0, maximumTipCurlDegrees1: 100, minimumSpreadDegrees: 0, maximumSpreadDegrees: 10)
        case .littleFinger:
            return FingerShapeConfiguration(minimumBaseCurlDegrees: -10, maximumBaseCurlDegrees: 90, minimumTipCurlDegrees1: 0, maximumTipCurlDegrees1: 100, minimumSpreadDegrees: 0, maximumSpreadDegrees: 20)
        default:
            return FingerShapeConfiguration(minimumBaseCurlDegrees: 0, maximumBaseCurlDegrees: 0, minimumTipCurlDegrees1: 0, maximumTipCurlDegrees1: 0, minimumSpreadDegrees: 0, maximumSpreadDegrees: 0)
        }
    }
}

public struct FingerShapeConfiguration {
    let minimumBaseCurlDegrees: Float
    let maximumBaseCurlDegrees: Float
    let minimumTipCurlDegrees1: Float
    let maximumTipCurlDegrees1: Float
    let minimumSpreadDegrees: Float
    let maximumSpreadDegrees: Float
}

public extension Set<HVJointOfFinger> {
    
    public static let fiveFingers: Set<HVJointOfFinger> = [.thumb, .indexFinger, .middleFinger, .ringFinger, .littleFinger]
    public static let fiveFingersAndForeArm: Set<HVJointOfFinger> = [.thumb, .indexFinger, .middleFinger, .ringFinger, .littleFinger, .forearm]
    public static let fiveFingersAndWrist: Set<HVJointOfFinger> = [.thumb, .indexFinger, .middleFinger, .ringFinger, .littleFinger, .metacarpal]
    public static let all: Set<HVJointOfFinger> = [.thumb, .indexFinger, .middleFinger, .ringFinger, .littleFinger, .metacarpal, .forearm]
    
    public var jointGroupNames: [HandSkeleton.JointName] {
        var jointNames: [HandSkeleton.JointName] = []
        for finger in HVJointOfFinger.allCases {
            if contains(finger) {
                jointNames.append(contentsOf: finger.jointGroupNames)
            }
        }
        return jointNames
    }
}
