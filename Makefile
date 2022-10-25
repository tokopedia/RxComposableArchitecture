build-library:
	swift build 

test-library:
	swift test --enable-code-coverage | xcpretty

test-example:
	mkdir -p derivedData && \
	cd Examples && \
	xcodebuild test \
		-project Examples.xcodeproj \
		-scheme Examples \
		-destination "platform=iOS Simulator,name=iPhone 13 Pro Max"
		-derivedDataPath ../derivedData \
		| xcpretty \
		&& cd .. && rm -rf derivedData

benchmark:
	swift run --configuration release \
		RxComposableArchitecture-Benchmark

.PHONY: build-library test-library test-example benchmark
