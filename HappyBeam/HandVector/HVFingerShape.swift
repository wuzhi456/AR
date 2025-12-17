//
//  HVFingerShape.swift
//  HappyBeam
//
//  Ported from HandVector
//

import ARKit

public struct HVFingerShape: Sendable, Equatable {
    public enum FingerShapeType: Int, Sendable, Equatable, CaseIterable {
        case baseCurl = 1
        case tipCurl = 2
        case fullCurl = 4
        case pinch = 8
        case spread = 16
    }
    
    
    public let finger: HVJointOfFinger
    public let fingerShapeTypes: Set<HVFingerShape.FingerShapeType>
    
    public let fullCurl: Float
    public let baseCurl: Float
    public let tipCurl: Float
    /// not avalible on thumb
    public let pinch: Float?
    /// not avalible on littleFinger
    public let spread: Float?
    
    
    public init(finger: HVJointOfFinger, fingerShapeType: HVFingerShape.FingerShapeType, joints: [HandSkeleton.JointName: HVJointInfo]) {
        self.init(finger: finger, fingerShapeTypes: [fingerShapeType], joints: joints)
    }
    public init(finger: HVJointOfFinger, fingerShapeTypes: Set<HVFingerShape.FingerShapeType> = Set(HVFingerShape.FingerShapeType.allCases), joints: [HandSkeleton.JointName: HVJointInfo]) {
        func linearInterpolate(lowerBound: Float, upperBound: Float, value: Float, clamp: Bool = true) -> Float {
            let p = (value-lowerBound)/(upperBound-lowerBound)
            if clamp {
                return simd_clamp(p, 0, 1)
            } else {
                return p
            }
        }
        
        self.finger = finger
        self.fingerShapeTypes = fingerShapeTypes
        
        var baseCurl: Float = 0
        var tipCurl: Float = 0
        var fullCurl: Float = 0
        var pinch: Float? = nil
        var spread: Float? = nil
        let config = finger.fingerShapeConfiguration
        
        if finger == .thumb {
            if fingerShapeTypes.contains(.baseCurl) {
                let joint = joints[finger.jointGroupNames[1]]!
                let xAxis = joint.transformToParent.columns.0
                let angle = atan2(xAxis.y, xAxis.x) / .pi * 180
                baseCurl = linearInterpolate(lowerBound: config.minimumBaseCurlDegrees, upperBound: config.maximumBaseCurlDegrees, value: angle)
                
//                print("baseCurl", angle, baseCurl)
            } else {
                baseCurl = 0
            }
            
            if fingerShapeTypes.contains(.tipCurl) {
                let joint = joints[finger.jointGroupNames[2]]!
                let xAxis = joint.transformToParent.columns.0
                let angle = atan2(xAxis.y, xAxis.x) / .pi * 180
                tipCurl = linearInterpolate(lowerBound: config.minimumTipCurlDegrees1, upperBound: config.maximumTipCurlDegrees1, value: angle)
                
//                print("tipCurl", angle, tipCurl)
            } else {
                tipCurl = 0
            }
            
            if fingerShapeTypes.contains(.fullCurl) {
                fullCurl = (baseCurl + tipCurl)/2
            }
            
            if fingerShapeTypes.contains(.spread) {
                let joint = joints[finger.jointGroupNames[1]]!
                let xAxis = joint.transform.columns.0
                
                let angle = -atan2(xAxis.z, xAxis.x) / .pi * 180
                spread = linearInterpolate(lowerBound: config.minimumSpreadDegrees, upperBound: config.maximumSpreadDegrees, value: angle)
                
//                print("spread", angle, spread)
            } else {
                spread = nil
            }
        } else {
            if fingerShapeTypes.contains(.baseCurl) {
                let joint = joints[finger.jointGroupNames.first!]!
                let xAxis = joint.transformToParent.columns.0
                let angle = atan2(xAxis.y, xAxis.x) / .pi * 180
                baseCurl = linearInterpolate(lowerBound: config.minimumBaseCurlDegrees, upperBound: config.maximumBaseCurlDegrees, value: angle)
                
//                print("baseCurl", angle, baseCurl)
            } else {
                baseCurl = 0
            }
            
            if fingerShapeTypes.contains(.tipCurl) {
                let joint = joints[finger.jointGroupNames[1]]!
                let xAxis = joint.transformToParent.columns.0
                let angle = atan2(xAxis.y, xAxis.x) / .pi * 180
                tipCurl = linearInterpolate(lowerBound: config.minimumTipCurlDegrees1, upperBound: config.maximumTipCurlDegrees1, value: angle)
                
//                print("tipCurl", angle, tipCurl)
            } else {
                tipCurl = 0
            }
            
            if fingerShapeTypes.contains(.fullCurl) {
                fullCurl = (baseCurl + tipCurl)/2
            }
            
            if fingerShapeTypes.contains(.spread) {
                let joint = joints[finger.jointGroupNames.first!]!
                let xAxis = joint.transform.columns.0
                
                let angle = -atan2(xAxis.z, xAxis.x) / .pi * 180
                spread = linearInterpolate(lowerBound: config.minimumSpreadDegrees, upperBound: config.maximumSpreadDegrees, value: angle)
                
//                print("spread", angle, spread)
            } else {
                spread = nil
            }
        }
        
        self.baseCurl = baseCurl
        self.tipCurl = tipCurl
        self.fullCurl = fullCurl
        self.pinch = pinch
        self.spread = spread
    }
}
