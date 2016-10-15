typedef LinePosition = {
	src : String,
	lines : { min:Int, max:Int },  // including–excluding offsets from zero
	codes : { min:Int, max:Int }   // unicode code points, including–excluding offsets from zero
}

