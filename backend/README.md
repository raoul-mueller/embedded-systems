# Setup

* ``git clone`` this repository
* ``cd backend``
* ``npm init``
* Copy ``.env.example`` and rename to ``.env``
* Fill out all fields in ``.env``
* ``npm run start`` or ``npm run dev`` for hot reload

# Fake Events

* Create an user by running ``node createFakeUser`` and copy the BoardID
* Run ``node fakeEventEmitter [interval] [boardID]`` to publish fake events
