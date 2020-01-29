import UIKit

class GaugeView: UIView {
	
	var outerBezelColor = UIColor(red: 0, green: 0.5, blue: 1, alpha: 1)
	var outerBezelWidth: CGFloat = 10
	
	var innerBezelColor = UIColor.white
	var innerBezelWidth: CGFloat = 5
	
	var insideColor = UIColor.white
	var segmentWidth: CGFloat = 20
	
	var segmentColors = [
		UIColor(red: 0.7, green: 0, blue: 0, alpha: 1),
		UIColor(red: 0, green: 0.5, blue: 0, alpha: 1),
		UIColor(red: 0, green: 0.5, blue: 0, alpha: 1),
		UIColor(red: 0, green: 0.5, blue: 0, alpha: 1),
		UIColor(red: 0.7, green: 0, blue: 0, alpha: 1)
	]
	
	var totalAngle: CGFloat = 270
	var rotation: CGFloat = -135
	
	var majorTickColor = UIColor.black
	var majorTickWidth: CGFloat = 2
	var majorTickLength: CGFloat = 25

	var minorTickColor = UIColor.black.withAlphaComponent(0.5)
	var minorTickWidth: CGFloat = 1
	var minorTickLength: CGFloat = 20
	var minorTickCount = 3

	var outerCenterDiscColor = UIColor(white: 0.9, alpha: 1)
	var outerCenterDiscWidth: CGFloat = 35
	var innerCenterDiscColor = UIColor(white: 0.7, alpha: 1)
	var innerCenterDiscWidth: CGFloat = 25
	
	var needleColor = UIColor.darkGray
	var needleWidth: CGFloat = 10
	let needle = UIView()
	
	let valueLabel = UILabel()
	var valueFont = UIFont.systemFont(ofSize: 56)
	var valueColor = UIColor.black
	
	var value: Float = 0.0 {
		didSet {
			// update the value label to show the exact number
			valueLabel.text = String(value)

			// figure out where the needle is, between 0 and 1
			let needlePosition = CGFloat(value) / 200

			// create a lerp from the start angle (rotation) through to the end angle (rotation + totalAngle)
			let lerpFrom = rotation
			let lerpTo = rotation + totalAngle

			// lerp from the start to the end position, based on the needle's position
			let needleRotation = lerpFrom + (lerpTo - lerpFrom) * needlePosition
			needle.transform = CGAffineTransform(rotationAngle: deg2rad(needleRotation))
		}
	}
	
	override func draw(_ rect: CGRect) {
		guard let ctx = UIGraphicsGetCurrentContext() else { return }
		drawBackground(in: rect, context: ctx)
		drawSegments(in: rect, context: ctx)
		drawTicks(in: rect, context: ctx)
		drawCenterDisc(in: rect, context: ctx)
	}
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		setUp()
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		setUp()
	}
	
	func setUp() {
		needle.backgroundColor = needleColor
		needle.translatesAutoresizingMaskIntoConstraints = false

		// make the needle a third of our height
		needle.bounds = CGRect(x: -innerCenterDiscWidth / 2, y: -innerCenterDiscWidth / 2, width: needleWidth, height: bounds.height / 3)

		// align it so that it is positioned and rotated from the bottom center
		needle.layer.anchorPoint = CGPoint(x: 0.5, y: 1)

		// now center the needle over our center point
		needle.center = CGPoint(x: bounds.midX, y: bounds.midY)
		valueLabel.font = valueFont
		valueLabel.text = "0"
		valueLabel.translatesAutoresizingMaskIntoConstraints = false
		addSubview(valueLabel)

		NSLayoutConstraint.activate([
			valueLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
			valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
		])
	}
	
	func drawCenterDisc(in rect: CGRect, context ctx: CGContext) {
		ctx.saveGState()
		ctx.translateBy(x: rect.midX, y: rect.midY)

		let outerCenterRect = CGRect(x: -outerCenterDiscWidth / 2, y: -outerCenterDiscWidth / 2, width: outerCenterDiscWidth, height: outerCenterDiscWidth)
		outerCenterDiscColor.set()
		ctx.fillEllipse(in: outerCenterRect)

		let innerCenterRect = CGRect(x: -innerCenterDiscWidth / 2, y: -innerCenterDiscWidth / 2, width: innerCenterDiscWidth, height: innerCenterDiscWidth)
		innerCenterDiscColor.set()
		ctx.fillEllipse(in: innerCenterRect)
		ctx.restoreGState()
	}
	
	func drawBackground(in rect: CGRect, context ctx: CGContext) {
		// draw the outer bezel as the largest circle
		outerBezelColor.set()
		ctx.fillEllipse(in: rect)
		
		// move in a little on each edge, then draw the inner bezel
		let innerBezelRect = rect.insetBy(dx: outerBezelWidth, dy: outerBezelWidth)
		innerBezelColor.set()
		ctx.fillEllipse(in: innerBezelRect)
		
		// finally, move in some more and draw the inside of our gauge
		let insideRect = innerBezelRect.insetBy(dx: innerBezelWidth, dy: innerBezelWidth)
		insideColor.set()
		ctx.fillEllipse(in: insideRect)
	}
	
	func drawSegments(in rect: CGRect, context ctx: CGContext) {
		// 1: Save the current drawing configuration
		ctx.saveGState()

		// 2: Move to the center of our drawing rectangle and rotate so that we're pointing at the start of the first segment
		ctx.translateBy(x: rect.midX, y: rect.midY)
		ctx.rotate(by: deg2rad(rotation) - (.pi / 2))

		// 3: Set up the user's line width
		ctx.setLineWidth(segmentWidth)

		// 4: Calculate the size of each segment in the total gauge
		let segmentAngle = deg2rad(totalAngle / CGFloat(segmentColors.count))

		// 5: Calculate how wide the segment arcs should be
		let segmentRadius = (((rect.width - segmentWidth) / 2) - outerBezelWidth) - innerBezelWidth

		// 6: Draw each segment
		for (index, segment) in segmentColors.enumerated() {
			// figure out where the segment starts in our arc
			let start = CGFloat(index) * segmentAngle

			// activate its color
			segment.set()

			// add a path for the segment
			ctx.addArc(center: .zero, radius: segmentRadius, startAngle: start, endAngle: start + segmentAngle, clockwise: false)

			// and stroke it using the activated color
			ctx.drawPath(using: .stroke)
		}

		// 7: Reset the graphics state
		ctx.restoreGState()
	}
	
	func deg2rad(_ number: CGFloat) -> CGFloat {
		return number * .pi / 180
	}
	
	func drawTicks(in rect: CGRect, context ctx: CGContext) {
		// save our clean graphics state
		ctx.saveGState()
		ctx.translateBy(x: rect.midX, y: rect.midY)
		ctx.rotate(by: deg2rad(rotation) - (.pi / 2))

		let segmentAngle = deg2rad(totalAngle / CGFloat(segmentColors.count))
		let segmentRadius = (((rect.width - segmentWidth) / 2) - outerBezelWidth) - innerBezelWidth

		// save the graphics state where we've moved to the center and rotated towards the start of the first segment
		ctx.saveGState()

		ctx.setLineWidth(majorTickWidth)
		majorTickColor.set()
		
		let majorEnd = segmentRadius + (segmentWidth / 2)
		let majorStart = majorEnd - majorTickLength
		
		for _ in 0...segmentColors.count {
			ctx.move(to: CGPoint(x: majorStart, y: 0))
			ctx.addLine(to: CGPoint(x: majorEnd, y: 0))
			ctx.drawPath(using: .stroke)
			ctx.rotate(by: segmentAngle)
		}

		// go back to the state we had before we drew the major ticks
		ctx.restoreGState()

		// save it again, because we're about to draw the minor ticks
		ctx.saveGState()

		// draw minor ticks
		ctx.setLineWidth(minorTickWidth)
		minorTickColor.set()

		let minorEnd = segmentRadius + (segmentWidth / 2)
		let minorStart = minorEnd - minorTickLength
		let minorTickSize = segmentAngle / CGFloat(minorTickCount + 1)

		for _ in 0 ..< segmentColors.count {
			ctx.rotate(by: minorTickSize)

			for _ in 0 ..< minorTickCount {
				ctx.move(to: CGPoint(x: minorStart, y: 0))
				ctx.addLine(to: CGPoint(x: minorEnd, y: 0))
				ctx.drawPath(using: .stroke)
				ctx.rotate(by: minorTickSize)
			}
		}

		// go back to the graphics state where we've moved to the center and rotated towards the start of the first segment
		ctx.restoreGState()

		// go back to the original graphics state
		ctx.restoreGState()
	}
	
}
