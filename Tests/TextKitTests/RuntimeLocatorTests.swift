@testable import TextKit
import Testing

struct RuntimeLocatorTests {
    @Test
    func prefersM4BackendOnM4Machines() {
        #expect(
            RuntimeLocator.preferredBackendFilenames(cpuBrand: "Apple M4") == [
                "libggml-cpu-apple_m4.so",
                "libggml-cpu-apple_m2_m3.so",
                "libggml-cpu-apple_m1.so"
            ]
        )
    }

    @Test
    func prefersM2M3BackendOnMidGenerationAppleSilicon() {
        #expect(
            RuntimeLocator.preferredBackendFilenames(cpuBrand: "Apple M3 Max") == [
                "libggml-cpu-apple_m2_m3.so",
                "libggml-cpu-apple_m1.so",
                "libggml-cpu-apple_m4.so"
            ]
        )
    }

    @Test
    func fallsBackToM1BackendWhenChipIsUnknown() {
        #expect(
            RuntimeLocator.preferredBackendFilenames(cpuBrand: "Apple M1") == [
                "libggml-cpu-apple_m1.so",
                "libggml-cpu-apple_m2_m3.so",
                "libggml-cpu-apple_m4.so"
            ]
        )
    }
}
