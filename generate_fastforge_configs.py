#!/usr/bin/env python3
"""
generate_fastforge_configs.py

Creates all Fastforge packaging config files for PI Task Watch:
 - linux/packaging/{appimage,deb,rpm}/make_config.yaml
 - windows/packaging/{exe,msix}/make_config.yaml
 - macos/packaging/{dmg,pkg}/make_config.yaml
"""

from pathlib import Path
import textwrap
from typing import Dict, List

# Define all templates here
TEMPLATES: Dict[str, str] = {
    "linux/packaging/appimage/make_config.yaml": textwrap.dedent(
        """\
        display_name: PI Task Watch
        icon: assets/logo.png
        keywords:
          - Productivity
          - Monitoring
          - Employee
          - Tracking
          - Screenshot
          - Activity
        generic_name: Employee Time Tracking Application
        actions:
          - name: Start Tracking
            label: start-tracking
            arguments:
              - --start
          - name: Pause Tracking
            label: pause-tracking
            arguments:
              - --pause
        categories:
          - Office
          - Utility
          - Monitor
        startup_notify: true
        include:
          - libcurl.so.4
        # metainfo: linux/packaging/appimage/org.primacyinfotech.pitaskwatch.appdata.xml
    """
    ),
    "linux/packaging/deb/make_config.yaml": textwrap.dedent(
        """\
        display_name: PI Task Watch
        package_name: pi-task-watch
        maintainer:
          name: Primacy Infotech
          email: info@primacyinfotech.com
        co_authors:
          - name: Development Team
            email: dev@primacyinfotech.com
        priority: optional
        section: utils
        installed_size: 8000
        essential: false
        icon: assets/logo.png

        postinstall_scripts:
          - echo "PI Task Watch has been installed successfully!"
        postuninstall_scripts:
          - echo "PI Task Watch has been uninstalled."

        keywords:
          - Employee
          - Monitoring
          - Time
          - Tracking
          - Screenshot
          - Productivity

        generic_name: Employee Time Tracking Application

        categories:
          - Office
          - Utility
          - Monitor

        startup_notify: true
        # metainfo: linux/packaging/deb/org.primacyinfotech.pitaskwatch.appdata.xml
    """
    ),
    "linux/packaging/rpm/make_config.yaml": textwrap.dedent(
        """\
        icon: assets/logo.png
        summary: Employee time tracking and monitoring solution for Odoo and custom applications
        group: Applications/Productivity
        vendor: Primacy Infotech
        packager: Primacy Infotech
        packagerEmail: info@primacyinfotech.com
        license: Proprietary
        url: https://primacyinfotech.com

        display_name: PI Task Watch

        keywords:
          - Employee
          - Monitoring
          - Time
          - Tracking
          - Screenshot
          - Productivity
          - Odoo

        generic_name: Employee Time Tracking Application

        categories:
          - Office
          - Utility
          - Monitor

        startup_notify: true
        # metainfo: linux/packaging/rpm/org.primacyinfotech.pitaskwatch.appdata.xml
    """
    ),
    "windows/packaging/exe/make_config.yaml": textwrap.dedent(
        """\
        app_id: 6D31B782-F721-4EC5-9F8A-29D53F92C4B1
        publisher: Primacy Infotech
        publisher_url: https://primacyinfotech.com
        display_name: PI Task Watch
        create_desktop_icon: true
        # setup_icon_file: windows/runner/resources/app_icon.ico
        locales:
          - en
        # script_template: custom_setup.iss
    """
    ),
    "windows/packaging/msix/make_config.yaml": textwrap.dedent(
        """\
        display_name: PI Task Watch
        msix_version: 1.0.0.0
        # logo_path: assets/logo.png
    """
    ),
    "macos/packaging/dmg/make_config.yaml": textwrap.dedent(
        """\
        title: PI Task Watch
        contents:
          - x: 448
            y: 344
            type: link
            path: '/Applications'
          - x: 192
            y: 344
            type: file
            path: PI Task Watch.app
    """
    ),
    "macos/packaging/pkg/make_config.yaml": textwrap.dedent(
        """\
        install-path: /Applications
        sign-identity: "Developer ID Installer: Primacy Infotech (TEAMID)"
    """
    ),
}


def create_configs(templates: Dict[str, str]) -> List[str]:
    """
    Create configuration files from templates.

    Args:
        templates: Dictionary mapping file paths to file content

    Returns:
        List of created file paths relative to the project root
    """
    root = Path(__file__).parent.resolve()
    written = []

    for rel_path, content in templates.items():
        dest = root / rel_path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(content, encoding="utf-8")
        written.append(str(dest.relative_to(root)))

    return written


def main() -> None:
    """Generate all Fastforge configuration files."""
    written = create_configs(TEMPLATES)

    print("\nGenerated Fastforge config files for PI Task Watch:")
    print(
        "An employee tracking tool developed by Primacy Infotech, Odoo official partner"
    )
    print(
        "Features: Screenshot capture, keyboard/mouse tracking, website activity monitoring, active window tracking"
    )
    print("\nFiles created:")
    for p in written:
        print(f"  - {p}")


if __name__ == "__main__":
    main()
