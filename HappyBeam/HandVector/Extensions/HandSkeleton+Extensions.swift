/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Extensions and utilities.
*/

import ARKit

extension HandSkeleton.Joint {
    var localPosition: simd_float3 {
        return anchorFromJointTransform.columns.3.xyz
    }
}

extension HandSkeleton.JointName {
    var name: String {
        return self.codableName.rawValue
    }
    
    var parentName: HandSkeleton.JointName? {
        switch self {
        case .thumbKnuckle: return .wrist
        case .thumbIntermediateBase: return .thumbKnuckle
        case .thumbIntermediateTip: return .thumbIntermediateBase
        case .thumbTip: return .thumbIntermediateTip
            
        case .indexFingerMetacarpal: return .wrist
        case .indexFingerKnuckle: return .indexFingerMetacarpal
        case .indexFingerIntermediateBase: return .indexFingerKnuckle
        case .indexFingerIntermediateTip: return .indexFingerIntermediateBase
        case .indexFingerTip: return .indexFingerIntermediateTip
            
        case .middleFingerMetacarpal: return .wrist
        case .middleFingerKnuckle: return .middleFingerMetacarpal
        case .middleFingerIntermediateBase: return .middleFingerKnuckle
        case .middleFingerIntermediateTip: return .middleFingerIntermediateBase
        case .middleFingerTip: return .middleFingerIntermediateTip
            
        case .ringFingerMetacarpal: return .wrist
        case .ringFingerKnuckle: return .ringFingerMetacarpal
        case .ringFingerIntermediateBase: return .ringFingerKnuckle
        case .ringFingerIntermediateTip: return .ringFingerIntermediateBase
        case .ringFingerTip: return .ringFingerIntermediateTip
            
        case .littleFingerMetacarpal: return .wrist
        case .littleFingerKnuckle: return .littleFingerMetacarpal
        case .littleFingerIntermediateBase: return .littleFingerKnuckle
        case .littleFingerIntermediateTip: return .littleFingerIntermediateBase
        case .littleFingerTip: return .littleFingerIntermediateTip
            
        case .forearmArm: return .forearmWrist
        case .forearmWrist: return .wrist
            
        default: return nil
        }
    }
}

extension simd_float4x4 {
    var float4Array: [SIMD4<Float>] {
        [columns.0, columns.1, columns.2, columns.3]
    }
    var positionReversed: simd_float4x4 {
        simd_float4x4(
            [columns.0,
             columns.1,
             columns.2,
             SIMD4<Float>(-columns.3.xyz, 1)]
        )
    }
}

