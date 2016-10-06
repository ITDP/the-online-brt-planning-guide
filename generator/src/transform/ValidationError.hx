package transform;

import transform.NewDocument;

typedef ValidationError = {
	fatal : Bool,
	msg : String,
	details : Dynamic,
	pos : Position
}

