// Generated from design/screens-more.html (the drawn plate archetypes). Do not edit by hand.

import MiseShared

extension PlateArtwork {
    static func elements(for plate: PlateArchetype) -> [PlateElement] {
        switch plate {
        case .creamySoup:
            return [
                .circle(cx: 80, cy: 80, r: 58, fill: .rice, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 80, cy: 82, r: 48, fill: .broth, stroke: nil, width: 0, opacity: 1),
                .path("M52 70c6-10 18-12 26-4", fill: nil, stroke: .tan, width: 4, opacity: 1),
                .ellipse(cx: 96, cy: 90, rx: 12, ry: 8, fill: .rice, opacity: 1),
                .ellipse(cx: 68, cy: 96, rx: 10, ry: 7, fill: .rice, opacity: 1),
                .circle(cx: 98, cy: 68, r: 7, fill: .tan, stroke: nil, width: 0, opacity: 1),
                .path("M60 60l8-12M106 104l10 10", fill: nil, stroke: .leaf, width: 3, opacity: 1),
                .circle(cx: 88, cy: 100, r: 3, fill: .chili, stroke: nil, width: 0, opacity: 1),
            ]
        case .salad:
            return [
                .path("M40 90c10-30 70-30 80 0-10 14-70 14-80 0z", fill: .herb, stroke: nil, width: 0, opacity: 0.55),
                .path("M50 84l20-14M62 92l24-16M78 96l22-14M56 76l14 2M90 74l16 10", fill: nil, stroke: .herb, width: 3, opacity: 1),
                .path("M70 80l6-9M98 84l6-9", fill: nil, stroke: .chili, width: 4, opacity: 1),
                .circle(cx: 66, cy: 98, r: 3.5, fill: .tan, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 84, cy: 100, r: 3.5, fill: .tan, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 100, cy: 96, r: 3.5, fill: .tan, stroke: nil, width: 0, opacity: 1),
                .path("M112 60a10 10 0 0 1 0 20z", fill: .herb, stroke: nil, width: 0, opacity: 1),
            ]
        case .friedNoodles:
            return [
                .path("M44 96c0-30 72-30 72 0s-72 30-72 0z", fill: .amber, stroke: nil, width: 0, opacity: 1),
                .path("M50 92c20-16 40 10 60-6M52 102c22-10 36 12 58-4M58 84c16-10 30 8 44-2", fill: nil, stroke: .tan, width: 3, opacity: 1),
                .path("M70 78c6-8 16-6 18 2-6 6-14 4-18-2z", fill: .rice, stroke: nil, width: 0, opacity: 1),
                .path("M92 92c6-8 16-6 18 2-6 6-14 4-18-2z", fill: .rice, stroke: nil, width: 0, opacity: 1),
                .path("M118 70a9 9 0 0 1 0 18z", fill: .herb, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 60, cy: 110, r: 2.5, fill: .tan, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 68, cy: 114, r: 2.5, fill: .tan, stroke: nil, width: 0, opacity: 1),
                .path("M48 70l-8-10", fill: nil, stroke: .leaf, width: 3, opacity: 1),
            ]
        case .curry:
            return [
                .circle(cx: 80, cy: 80, r: 56, fill: .rice, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 80, cy: 82, r: 46, fill: .herb, stroke: nil, width: 0, opacity: 1),
                .ellipse(cx: 70, cy: 78, rx: 12, ry: 8, fill: .rice, opacity: 1),
                .ellipse(cx: 94, cy: 92, rx: 11, ry: 7, fill: .rice, opacity: 1),
                .circle(cx: 92, cy: 70, r: 6, fill: .leaf, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 66, cy: 96, r: 5, fill: .leaf, stroke: nil, width: 0, opacity: 1),
                .path("M80 60c4-6 10-6 14-2-4 4-10 4-14 2z", fill: .leaf, stroke: nil, width: 0, opacity: 1),
                .path("M60 110c6-4 14-2 16 4-6 2-12 0-16-4z", fill: .leaf, stroke: nil, width: 0, opacity: 1),
                .path("M104 108l4-8", fill: nil, stroke: .chili, width: 4, opacity: 1),
            ]
        case .riceInFruit:
            return [
                .path("M30 90c0-26 100-26 100 0-20 14-80 14-100 0z", fill: .amber, stroke: nil, width: 0, opacity: 1),
                .path("M36 86c20-8 68-8 88 0", fill: nil, stroke: .tan, width: 2, opacity: 1),
                .path("M42 94c18 8 58 8 76 0-18 6-58 6-76 0z", fill: .rice, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 62, cy: 92, r: 4, fill: .broth, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 84, cy: 96, r: 4, fill: .broth, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 100, cy: 90, r: 4, fill: .broth, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 74, cy: 98, r: 2.5, fill: .tan, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 92, cy: 100, r: 2.5, fill: .tan, stroke: nil, width: 0, opacity: 1),
                .path("M118 72l10-26M124 74l16-20M112 70l2-28", fill: nil, stroke: .leaf, width: 4, opacity: 1),
            ]
        case .greens:
            return [
                .path("M40 100c10-30 30-50 80-44-10 30-40 50-80 44z", fill: .herb, stroke: nil, width: 0, opacity: 1),
                .path("M48 96c14-22 34-36 62-36M56 100c12-14 30-26 54-28M66 102c10-8 24-16 40-18", fill: nil, stroke: .leaf, width: 3, opacity: 1),
                .path("M74 74l6-10M96 78l5-9", fill: nil, stroke: .chili, width: 4, opacity: 1),
                .circle(cx: 60, cy: 88, r: 3, fill: .rice, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 86, cy: 94, r: 3, fill: .rice, stroke: nil, width: 0, opacity: 1),
            ]
        case .friedChicken:
            return [
                .path("M46 86c-2-16 14-26 28-18 10-8 26-4 30 10 10 2 16 14 8 22-10 10-54 12-66-4-4-4-2-8 0-10z", fill: .amber, stroke: nil, width: 0, opacity: 1),
                .path("M58 76c8-6 18-4 22 4M84 70c8 0 14 6 14 12", fill: nil, stroke: .tan, width: 3, opacity: 1),
                .circle(cx: 62, cy: 100, r: 2.5, fill: .tan, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 96, cy: 104, r: 2.5, fill: .tan, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 110, cy: 92, r: 2.5, fill: .tan, stroke: nil, width: 0, opacity: 1),
                .path("M116 70a9 9 0 0 1 0 18z", fill: .herb, stroke: nil, width: 0, opacity: 1),
                .path("M44 62l-6-8", fill: nil, stroke: .leaf, width: 3, opacity: 1),
            ]
        case .wholeFish:
            return [
                .path("M34 82c16-22 70-22 92 0-22 20-76 20-92 0z", fill: .rice, stroke: nil, width: 0, opacity: 1),
                .path("M116 70l14-10-4 22-10-6", fill: .tan, stroke: nil, width: 0, opacity: 1),
                .path("M48 82c12-8 56-8 70 0", fill: nil, stroke: .tan, width: 2, opacity: 1),
                .path("M60 76l6-4M72 74l6-4M84 74l6-4M96 76l6-4", fill: nil, stroke: .tan, width: 2, opacity: 1),
                .circle(cx: 50, cy: 80, r: 2.5, fill: .leaf, stroke: nil, width: 0, opacity: 1),
                .path("M40 106a10 10 0 0 1 20 0z", fill: .herb, stroke: nil, width: 0, opacity: 1),
                .path("M96 100l6-10", fill: nil, stroke: .chili, width: 4, opacity: 1),
                .path("M110 102l10 6", fill: nil, stroke: .leaf, width: 3, opacity: 1),
            ]
        case .sweet:
            return [
                .path("M44 96c0-18 30-24 40-10 8-10 32-6 32 10-6 12-18 18-36 16-16-2-30-6-36-16z", fill: .rice, stroke: nil, width: 0, opacity: 1),
                .path("M78 60c20-14 44 4 38 30-10-4-18-8-26-6-8-6-14-14-12-24z", fill: .amber, stroke: nil, width: 0, opacity: 1),
                .path("M50 102c10 6 24 8 36 6", fill: nil, stroke: .tan, width: 2, opacity: 1),
                .circle(cx: 60, cy: 90, r: 2.5, fill: .tan, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 70, cy: 96, r: 2.5, fill: .tan, stroke: nil, width: 0, opacity: 1),
                .path("M52 112c6 2 12 2 18 0", fill: nil, stroke: .broth, width: 3, opacity: 1),
            ]
        case .coconut:
            return [
                .circle(cx: 80, cy: 84, r: 40, fill: .tan, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 80, cy: 84, r: 40, fill: nil, stroke: .rice, width: 6, opacity: 0.7),
                .circle(cx: 80, cy: 84, r: 22, fill: .rice, stroke: nil, width: 0, opacity: 1),
                .path("M92 50l10-22", fill: nil, stroke: .leaf, width: 4, opacity: 1),
                .path("M86 52l4-10", fill: nil, stroke: .herb, width: 4, opacity: 1),
            ]
        case .drink:
            return [
                .rect(x: 56, y: 34, w: 48, h: 90, rx: 10, fill: .amber, opacity: 1),
                .rect(x: 56, y: 34, w: 48, h: 26, rx: 10, fill: .rice, opacity: 1),
                .rect(x: 56, y: 48, w: 48, h: 12, rx: 0, fill: .broth, opacity: 1),
                .path("M90 24l-6 28", fill: nil, stroke: .leaf, width: 4, opacity: 1),
                .circle(cx: 68, cy: 100, r: 4, fill: .tan, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 84, cy: 110, r: 4, fill: .tan, stroke: nil, width: 0, opacity: 1),
            ]
        case .porridge:
            return [
                .circle(cx: 80, cy: 80, r: 58, fill: .rice, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 80, cy: 82, r: 48, fill: .broth, stroke: nil, width: 0, opacity: 0.6),
                .circle(cx: 74, cy: 80, r: 12, fill: .amber, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 74, cy: 80, r: 6, fill: .broth, stroke: nil, width: 0, opacity: 1),
                .path("M96 92l12 8M58 100l-8 10", fill: nil, stroke: .leaf, width: 3, opacity: 1),
                .circle(cx: 100, cy: 72, r: 3, fill: .tan, stroke: nil, width: 0, opacity: 1),
            ]
        case .chickenRice:
            return [
                .path("M40 92c0-24 36-34 52-20 18-8 36 4 30 22-6 16-74 18-82-2z", fill: .rice, stroke: nil, width: 0, opacity: 1),
                .path("M64 70c10-12 34-12 46 0-2 10-44 12-46 0z", fill: .broth, stroke: nil, width: 0, opacity: 1),
                .path("M70 74h34M72 80h30", fill: nil, stroke: .tan, width: 2, opacity: 1),
                .path("M116 96l12 8M42 100l-8 6", fill: nil, stroke: .herb, width: 4, opacity: 1),
                .circle(cx: 118, cy: 66, r: 8, fill: .herb, stroke: nil, width: 0, opacity: 1),
            ]
        case .noodleSoup:
            return [
                .circle(cx: 80, cy: 80, r: 58, fill: .rice, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 80, cy: 82, r: 48, fill: .broth, stroke: nil, width: 0, opacity: 1),
                .path("M50 84c10-10 20 10 30 0s20 10 30 0M54 94c10-10 20 10 30 0s18 8 26 0", fill: nil, stroke: .rice, width: 4, opacity: 1),
                .ellipse(cx: 70, cy: 68, rx: 10, ry: 6, fill: .tan, opacity: 1),
                .ellipse(cx: 94, cy: 70, rx: 9, ry: 6, fill: .tan, opacity: 1),
                .path("M98 100l10-8M60 106l8-6", fill: nil, stroke: .leaf, width: 3, opacity: 1),
            ]
        case .riceWithEgg:
            return [
                .path("M34 92c0-20 40-28 52-14 14-8 40-2 40 14-8 14-84 18-92 0z", fill: .rice, stroke: nil, width: 0, opacity: 1),
                .path("M78 74c4-14 34-16 40 0-6 12-36 12-40 0z", fill: .tan, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 60, cy: 76, r: 16, fill: .hex(0xFFFFFF), stroke: nil, width: 0, opacity: 1),
                .circle(cx: 60, cy: 76, r: 7, fill: .amber, stroke: nil, width: 0, opacity: 1),
                .path("M96 66l6-6M108 72l8-4", fill: nil, stroke: .leaf, width: 4, opacity: 1),
                .path("M90 82l4-7", fill: nil, stroke: .chili, width: 3, opacity: 1),
            ]
        case .spicySoup:
            return [
                .circle(cx: 80, cy: 80, r: 58, fill: .rice, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 80, cy: 82, r: 48, fill: .amber, stroke: nil, width: 0, opacity: 1),
                .path("M64 70c6-8 16-6 18 2-6 6-14 4-18-2z", fill: .rice, stroke: nil, width: 0, opacity: 1),
                .path("M90 92c6-8 16-6 18 2-6 6-14 4-18-2z", fill: .rice, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 70, cy: 98, r: 5, fill: .rice, stroke: nil, width: 0, opacity: 1),
                .path("M98 66l10-6M54 90l-6 8", fill: nil, stroke: .leaf, width: 3, opacity: 1),
                .path("M84 76l4-7", fill: nil, stroke: .chili, width: 3, opacity: 1),
            ]
        case .friedRice:
            return [
                .path("M36 90c0-26 88-26 88 0-16 14-72 14-88 0z", fill: .broth, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 62, cy: 84, r: 3, fill: .herb, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 84, cy: 80, r: 3, fill: .herb, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 98, cy: 88, r: 3, fill: .amber, stroke: nil, width: 0, opacity: 1),
                .circle(cx: 72, cy: 92, r: 3, fill: .amber, stroke: nil, width: 0, opacity: 1),
                .path("M118 70a9 9 0 0 1 0 18z", fill: .herb, stroke: nil, width: 0, opacity: 1),
                .path("M44 104h70", fill: nil, stroke: .rice, width: 5, opacity: 1),
            ]
        case .fishRolls:
            return [
                .ellipse(cx: 62, cy: 82, rx: 18, ry: 14, fill: .tan, opacity: 1),
                .ellipse(cx: 96, cy: 82, rx: 18, ry: 14, fill: .tan, opacity: 1),
                .path("M50 82c8-4 16-4 24 0M84 82c8-4 16-4 24 0", fill: nil, stroke: .amber, width: 3, opacity: 1),
                .path("M58 104c10 6 30 6 44 0", fill: nil, stroke: .herb, width: 5, opacity: 1),
                .path("M112 60a9 9 0 0 1 0 18z", fill: .broth, stroke: nil, width: 0, opacity: 1),
            ]
        case .generic:
            return elements(for: .friedRice)
        }
    }
}

