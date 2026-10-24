//
// ClosedRange+Conversion.swift
// SliderControl
//
// Created by Alexander Chekel on 30.04.2024.
// Copyright © 2024 Alexander Chekel. All rights reserved.
//

import Foundation

extension ClosedRange where Bound: BinaryFloatingPoint {
    func convert(value: Bound, to newRange: ClosedRange<Bound>) -> Bound {
        guard lowerBound != upperBound else { return newRange.lowerBound }
        return (((value - lowerBound) * (newRange.upperBound - newRange.lowerBound)) / (upperBound - lowerBound)) + newRange.lowerBound
    }
}
