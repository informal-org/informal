To setup virtualenv
from the project base directory (where readme is)
python3 -m venv .aaenv
source .aaenv/bin/activate to activate the virtualenv
Install poetry
pip install poetry

The install all of the other dependencies
poetry install

To add a new dependency
poetry add mydependency


Create a .env in appy dir with the environment variables.
