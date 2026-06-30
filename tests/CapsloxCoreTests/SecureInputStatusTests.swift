import Testing
@testable import CapsloxCore

@Test func secureInputStatusParsesPidFromIORegistryOutput() {
    let output = """
      |   "IOConsoleUsers" = ({"kCGSSessionOnConsoleKey"=Yes,"kCGSSessionSecureInputPID"=86543,"kCGSessionLoginDoneKey"=Yes})
    """

    #expect(SecureInputStatus.parseIORegistryOutput(output)?.pid == 86543)
}

@Test func secureInputStatusIgnoresOutputWithoutSecureInputPid() {
    let output = """
      |   "IOConsoleUsers" = ({"kCGSSessionOnConsoleKey"=Yes,"kCGSessionLoginDoneKey"=Yes})
    """

    #expect(SecureInputStatus.parseIORegistryOutput(output) == nil)
}

@Test func processOutputDrainsLargeStdoutBeforeWaitingForExit() {
    let output = ProcessOutput.run(
        executablePath: "/usr/bin/perl",
        arguments: ["-e", "print \"x\" x 200000"]
    )

    #expect(output?.count == 200000)
}

@Test func secureInputStatusDescribesLiveOwner() {
    let status = SecureInputStatus(
        pid: 86543,
        owner: .init(pid: 86543, name: "Google Chrome", bundleIdentifier: "com.google.Chrome")
    )

    #expect(CapsloxPresentation.secureInputStatusTitle == "Secure Input")
    #expect(CapsloxPresentation.secureInputBlockedValue == "Blocked")
    #expect(CapsloxPresentation.secureInputDetail(for: status) == "Google Chrome is using macOS Secure Input, so CapsMov can't read keys for now. This is expected while a password field is focused—move focus out of it (or quit Google Chrome) and CapsMov resumes on its own.")
    #expect(CapsloxPresentation.secureInputActionTitle(for: status) == "Quit Google Chrome")
}

@Test func secureInputStatusDescribesStalePid() {
    let status = SecureInputStatus(pid: 86543, owner: nil)

    #expect(CapsloxPresentation.secureInputDetail(for: status) == "macOS still reports Secure Input from pid 86543, which has already exited—a known macOS glitch. It usually clears by itself; if CapsMov still can't read keys, lock the screen or log out and back in to reset it.")
    #expect(CapsloxPresentation.secureInputActionTitle(for: status) == "Refresh")
}
