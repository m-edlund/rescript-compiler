(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)




let (@>) (b, v) acc =
  if b then
    v :: acc
  else
      acc


let (//) = Filename.concat

let rec process_line cwd filedir  line =
  let line = Ext_string.trim line in
  let len = String.length line in
  if len = 0 then []
  else
    match line.[0] with
    | '#' -> []
    | _ ->
      let segments =
        Ext_string.split_by ~keep_empty:false (fun x -> x = ' ' || x = '\t' ) line
      in
      begin
        match segments with
        | ["include" ;  path ]
          ->
          (* prerr_endline path;  *)
          read_lines cwd  (filedir// path)
        | [ x ]  ->
          let ml = filedir // x ^ ".ml" in
          let mli = filedir // x ^ ".mli" in
          let ml_exists, mli_exists = Sys.file_exists ml , Sys.file_exists mli in
          if not ml_exists && not mli_exists then
            begin
              prerr_endline (filedir //x ^ " not exists");
              []
            end
          else
            (ml_exists, ml) @> (mli_exists , mli) @> []
        | _
          ->  Ext_pervasives.failwithf ~loc:__LOC__ "invalid line %s" line
      end
and read_lines (cwd : string) (file : string) : string list =
  file
  |> Ext_io.rev_lines_of_file
  |> List.fold_left (fun acc f ->
      let filedir  =   Filename.dirname file in
      let extras = process_line  cwd filedir f in
      extras  @ acc
    ) []

let implementation sourcefile =
  let content = Ext_io.load_file sourcefile in
  let ast =
    let oldname = !Location.input_name in
    Location.input_name := sourcefile ;
    let lexbuf = Lexing.from_string content in
    Location.init lexbuf sourcefile ;
    match Parse.implementation  lexbuf
    with
    | exception e ->
      Location.input_name := oldname;
      raise e
    | ast ->
      Location.input_name := oldname ;
      ast
  in
  ast, content

let interface sourcefile =
  let content = Ext_io.load_file sourcefile in
  let ast =
    let oldname = !Location.input_name in
    Location.input_name := sourcefile ;
    let lexbuf = Lexing.from_string content in
    Location.init lexbuf sourcefile;
    match Parse.interface  lexbuf with
    | exception e ->
      Location.input_name := oldname ;
      raise e
    | ast ->
      Location.input_name := oldname ;
      ast in
  ast, content


let emit out_chan name =
  output_string out_chan "#1 \"";
  (*Note here we do this is mostly to avoid leaking user's
    information, like private path, in the future, we can have
    a flag
  *)
  output_string out_chan (Filename.basename name) ;
  output_string out_chan "\"\n"

let decorate_module out_chan base mli_name ml_name mli_content ml_content =
  let base = String.capitalize base in
  output_string out_chan "module ";
  output_string out_chan base ;
  output_string out_chan " : sig \n";

  emit out_chan mli_name ;
  output_string out_chan mli_content;

  output_string out_chan "\nend = struct\n";
  emit out_chan  ml_name ;
  output_string out_chan ml_content;
  output_string out_chan "\nend\n"

let decorate_module_only out_chan base ml_name ml_content =
  let base = String.capitalize base in
  output_string out_chan "module \n";
  output_string out_chan base ;
  output_string out_chan "\n= struct\n";
  emit out_chan  ml_name;
  output_string out_chan ml_content;
  output_string out_chan "\nend\n"

let decorate_interface_only out_chan  base mli_content mli_name =
  let base = String.capitalize base in
  output_string out_chan "module type \n";
  output_string out_chan base ;
  output_string out_chan "\n= sig\n";

  emit out_chan mli_name;
  output_string out_chan mli_content;

  output_string out_chan "\nend\n"

let mllib = ref None
let set_string s = mllib := Some s

let batch_files = ref []
let collect_file name =
  batch_files := name :: !batch_files

let output_file = ref None
let set_output file = output_file := Some file
let header_option = ref false

let specs : (string * Arg.spec * string) list =
  [
    "-bs-mllib", (Arg.String set_string),
    " Files collected from mllib";
    "-o", (Arg.String set_output),
    " Set output file (default to stdout)" ;
    "-with-header", (Arg.Set header_option),
    " with header of time stamp(can also be set with env variable BS_RELEASE_BUILD)"
  ]


let anonymous filename =
  collect_file filename

let usage = "Usage: bspack <options> <files>\nOptions are:"
let _ =
  let _loc = Location.none in
  try
    (Arg.parse specs anonymous usage;
     let command_files =  !batch_files in
     let files =
       (match !mllib with
        | Some s
          -> read_lines (Sys.getcwd ()) s
        | None -> []) @ command_files in

     let ast_table =
       Ast_extract.build
         Format.err_formatter files
         (fun _ppf sourcefile -> implementation sourcefile
         )
         (fun _ppf sourcefile -> interface sourcefile) in
     let tasks = Ast_extract.sort fst  fst ast_table in


     let local_time = Unix.(localtime (gettimeofday ())) in
     (* emit code now *)
     let out_chan =
       match !output_file with
       | None -> stdout
       | Some file -> open_out file  in
     (if  !header_option ||
          (try ignore (Sys.getenv "BS_RELEASE_BUILD") ; true with _ -> false)
      then
        output_string out_chan
          (Printf.sprintf "(** Generated by bspack %02d/%02d-%02d:%02d *)\n" (local_time.tm_mon + 1) local_time.tm_mday
             local_time.tm_hour local_time.tm_min))
     ;   

     tasks |> Queue.iter
       (fun module_ ->
          let t =
            match (String_map.find  module_ ast_table).ast_info with
            | exception Not_found -> failwith (module_ ^ "not found")
            | Ml (sourcefile, (_, content), _)
              ->
              `Ml (module_, content, sourcefile)
            | Mli (sourcefile , (_, content), _) ->
              `Mli (module_, content, sourcefile)
            | Ml_mli (ml_sourcefile, (_, ml_content), _, mli_sourcefile,  (_, mli_content), _)
              ->
              `All (module_, ml_content, ml_sourcefile, mli_content, mli_sourcefile) in
          match t with
          | `All (base, ml_content,ml_name, mli_content, mli_name) ->
            decorate_module out_chan base mli_name ml_name mli_content ml_content

          | `Ml (base, ml_content, ml_name) ->
            decorate_module_only out_chan base ml_name ml_content
          | `Mli (base, mli_content, mli_name) ->
            decorate_interface_only out_chan base mli_content mli_name
       );

     (if out_chan != stdout then close_out out_chan)
    )
  with x ->
    begin
      Location.report_exception Format.err_formatter x ;
      exit 2
    end