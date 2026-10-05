from setuptools import setup

setup(
    name="slagskibe",
    version="0.2.0",
    description="Sænke Slagskibe – TUI-netværksspil med indbygget TCP (tidligere battleship)",
    packages=["slagskibe"],
    package_dir={"slagskibe": "slagskibe"},
    python_requires=">=3.10",
    install_requires=[
        "textual>=0.70.0",
        "pyyaml>=6.0",
    ],
    entry_points={
        "console_scripts": [
            "slagskibe=slagskibe.main:run",
        ],
    },
)