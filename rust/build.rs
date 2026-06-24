fn main() {
    #[cfg(target_os = "macos")] {
        println!("cargo:rustc-link-lib=framework=Carbon");
        println!("cargo:rustc-link-lib=framework=ApplicationServices");
    }
    
    #[cfg(target_os = "windows")] {
        println!("cargo:rustc-link-lib=user32");
        println!("cargo:rustc-link-lib=kernel32");
        println!("cargo:rustc-link-lib=psapi");
        println!("cargo:rustc-link-lib=ntdll");
    }
}
