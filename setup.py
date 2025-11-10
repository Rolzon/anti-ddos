from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

with open("requirements.txt", "r", encoding="utf-8") as fh:
    requirements = [line.strip() for line in fh if line.strip() and not line.startswith("#")]

setup(
    name="antiddos",
    version="1.0.0",
    author="Anti-DDoS Team",
    description="Comprehensive DDoS protection system for Ubuntu 22.04",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/yourusername/anti-ddos",
    package_dir={"": "src"},
    packages=find_packages(where="src"),
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: System Administrators",
        "Topic :: System :: Networking :: Firewalls",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Operating System :: POSIX :: Linux",
    ],
    python_requires=">=3.10",
    install_requires=requirements,
    entry_points={
        "console_scripts": [
            "antiddos-monitor=antiddos.monitor:main",
            "antiddos-ssh=antiddos.ssh_protection:main",
            "antiddos-xcord=antiddos.xcord:main",
            "antiddos-cli=antiddos.cli:main",
        ],
    },
)
