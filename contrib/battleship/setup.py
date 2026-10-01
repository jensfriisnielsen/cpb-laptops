from setuptools import find_packages, setup

setup(
    name="battleship",
    version="0.1.0",
    description="Sænke Slagskibe – simpelt TUI-netværksspil for elever",
    packages=find_packages(),
    python_requires=">=3.10",
    install_requires=[
        "textual>=0.70.0",
        "pyyaml>=6.0",
    ],
    entry_points={
        "console_scripts": [
            "battleship=battleship.main:run",
        ],
    },
)
