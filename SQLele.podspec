Pod::Spec.new do |s|

    s.name         = "SQLele"
    s.version      = "0.0.1"
    s.summary      = "A wrapper around C SQLite to use or build upon."

    s.description  = <<-DESC
    SQLele wraps the C SQLite API so you don't have to. Use it as-is for low-level
    SQLite access, or to build awesome libraries upon without dealing with the C API.
                   DESC

    s.homepage     = "https://github.com/ahti/SQLele"

    s.license      = { :type => "MIT", :file => "LICENSE" }

    s.author       = { "Lukas Stabe" => "lukas@stabe.de" }

    s.ios.deployment_target = "10.0"
    s.osx.deployment_target = "10.12"
    s.tvos.deployment_target = "10.0"

    s.source       = { :git => "https://github.com/ahti/SQLele.git", :tag => "#{s.version}" }

    s.source_files = "Sources/**/*.swift"

    s.test_spec 'Tests' do |test|
        test.source_files  = "Tests/**/*.swift"
        test.exclude_files = "Tests/LinuxMain.swift"
        test.framework     = "XCTest"
    end

end
