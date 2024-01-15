build-library:
	swift build 

test-library:
	swift test --enable-code-coverage | xcpretty
	
default:
	make build-library && make test-library

test-example:
	mkdir -p derivedData && \
	cd Examples && \
	xcodebuild test \
	-project Examples.xcodeproj \
	-scheme Examples \
	-destination "platform=iOS Simulator"
	-derivedDataPath ../derivedData \
	| xcpretty \
	&& rm -rf ../derivedData

benchmark:
	swift run --configuration release \
		RxComposableArchitecture-Benchmark

.PHONY: build-library test-library test-example benchmark
