# 1 "ext/hash_set.cppo.ml"
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
# 25
type key = int
let key_index (h :  _ Hash_set_gen.t ) (key : key) =
  (Bs_hash_stubs.hash_int  key) land (Array.length h.data - 1)
let eq_key = Ext_int.equal 


# 44
type  t = key  Hash_set_gen.t 
let create = Hash_set_gen.create
let clear = Hash_set_gen.clear
let reset = Hash_set_gen.reset
let copy = Hash_set_gen.copy
let iter = Hash_set_gen.iter
let fold = Hash_set_gen.fold
let length = Hash_set_gen.length
let stats = Hash_set_gen.stats
let elements = Hash_set_gen.elements



let remove (h : t) key =  
  let i = key_index h key in
  let h_data = h.data in
  let old_h_size = h.size in 
  let new_bucket = Hash_set_gen.remove_bucket eq_key key h (Array.unsafe_get h_data i) in
  if old_h_size <> h.size then  
    Array.unsafe_set h_data i new_bucket



let add (h : t) key =
  let i = key_index h key  in 
  if not (Hash_set_gen.small_bucket_mem eq_key key  (Array.unsafe_get h.data i)) then 
    begin 
      h.data.(i) <- key :: h.data.(i);
      h.size <- h.size + 1 ;
      if h.size > Array.length h.data lsl 1 then Hash_set_gen.resize key_index h
    end

let check_add (h : t) key =
  let i = key_index h key  in 
  if not (Hash_set_gen.small_bucket_mem eq_key key  (Array.unsafe_get h.data i)) then 
    begin 
      h.data.(i) <- key :: h.data.(i);
      h.size <- h.size + 1 ;
      if h.size > Array.length h.data lsl 1 then Hash_set_gen.resize key_index h;
      true 
    end
  else false 


let mem (h :  t) key =
  Hash_set_gen.small_bucket_mem eq_key key (Array.unsafe_get h.data (key_index h key)) 