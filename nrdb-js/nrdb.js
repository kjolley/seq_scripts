//NRDB-js
//Javascript implementation of NRDB, inspired by original 
//program by Warren Gish.
//Written by Keith Jolley
//Copyright (c) 2016 Keith Jolley
//GPLv3.

function analyse() {
	var output = document.getElementById("output");
	var seq_obj = readFasta();
	var seq_hash = {}
	for (var i = 0; i < seq_obj.length; i++) {
		if (seq_hash[seq_obj[i].seq] == null) {
			seq_hash[seq_obj[i].seq] = [];
		}
		seq_hash[seq_obj[i].seq].push(seq_obj[i].id);
	}
	var dupes = [];
	for ( var seq in seq_hash) {
		if (seq_hash[seq].length > 1) {
			dupes.push(seq_hash[seq].join("; "));
		}
	}
	var results = "<h2>Duplicates</h2>\n";
	if (dupes.length) {
		results += "<ul>\n";
		for (var i = 0; i < dupes.length; i++) {
			results += "<li>" + dupes[i] + "</li>\n";
		}
		results += "</ul>\n";
	} else {
		results += "<p>No duplicates found.</p>\n";
	}
	if (seq_obj.length) {
		results += "<h2>Unique alleles</h2>\n";
		results += "<textarea name=\"unique\" id=\"unique\" rows=\"6\" cols=\"70\">\n";
		var id = 1;
		for ( var seq in seq_hash) {
			if (document.getElementById("renumber").checked) {
				var name = "";
				if (document.getElementById("prefix").value) {
					name = document.getElementById("prefix").value;
				}
				name += id;
				results += ">" + name + "\n";
			} else {
				results += ">" + seq_hash[seq].join("|") + "\n";
			}
			results += seq + "\n";
			id++;
		}
		results += "</textarea>\n";
	}
	output.innerHTML = results;

}
function readFasta() {
	var fasta = document.getElementById("sequence").value;
	var lines = fasta.split(/\r?\n/);
	var seq_obj = [];
	var current_seq = {};
	var sequence = "";
	for (var i = 0; i < lines.length; i++) {
		if (lines[i].match(/^\s*$/)) {
			continue;
		}
		var id = lines[i].match(/^>(.*)$/);
		if (id != null) {
			if (sequence.length) {
				current_seq.seq = sequence;
				seq_obj.push(current_seq);
				sequence = "";
				current_seq = {};
			}
			current_seq.id = id[1];
		} else {
			lines[i] = lines[i].replace(/\s/g, "");
			lines[i] = lines[i].toUpperCase();

			sequence += lines[i];
		}
	}
	current_seq.seq = sequence;
	if (sequence.length) {
		seq_obj.push(current_seq);
	}
	return seq_obj;
}