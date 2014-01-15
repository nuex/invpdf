BEGIN { 
  cid = "none"
  ccnt = 0
  if (!closing) closing = "Thank you for your business."
}

FNR == 1 { fcnt++ }

{
  if (fcnt == 1) {
    customer()
  } else if (fcnt == 2 && FNR ==1) {
    after_customer(); invoice()
  } else {
    invoice()
  }
  next
}
    
END {
  if (errors) exit 1
  print "\\documentclass{letter}"
  print "\\usepackage{longtable}"
  print "\\address{" address() "}"
  print "\\date{" date "}"
  print ""
  print "\\begin{document}"
  print "  \\begin{letter}{" customer_address "}"
  print "    \\opening{INVOICE \\#" inv_number "}"
  print "    \\renewcommand*{\\arraystretch}{1.4}"
  print "    \\begin{longtable}{p{5cm}lrrr}"
  print_projects()
  print_discounts()
  print "     \\hline"
  print "     \\hline"
  grandtotal_to_usd = sprintf("%0.2f", grandtotal/100)
  print "     \\textbf{Total}&& & & {" grandtotal_to_usd "}"
  print "    \\end{longtable}"
  print "    \\closing{" closing "}"
  print "  \\end{letter}"
  print "\\end{document}"
}

function customer() {
  if (NF == 0) {
    cid = "none"
  } else if (cid != "none") {
    customers[ccnt] = customers[ccnt] " \\\\ " $0
  } else {
    ccnt++
    cid = $0
    cmap[cid] = ccnt
    customers[ccnt] = $0
  }
}

function invoice() {
  # ignore blank lines and comments
  if (NF == 0 || $0 ~ /^;/) return

  # scrape off inline comments and reset $0 and NF
  if (match($0, /;/)) {
    comment_start = RSTART
    line = $0
    for (i = 1; i <= NF; i++) {
      if ($i ~ /^;/) {
        NF = NF - ((NF + 1) - i)
        $0 = substr(line, 0, comment_start - 1)
        break
      }
    }
  }

  if (!inv_number && !date && !customer_address) {
    parse_inv_number(); parse_date(); parse_customer_address()
  } else if ($0 ~ /^[[:alnum:]_].*-[0-9|\$]/) {
    parse_discount()
  } else if ($0 ~ /^[[:alnum:]_].*/) {
    parse_project()
  } else if ($0 ~ /^[[:blank:]_]{2}/) {
    parse_line_item()
  } else {
    error("unexpected line encountered at " FNR)
  }
  
}

function parse_inv_number() {
  if ($1 ~ /INV#[[:alnum:]_]+/) {
    sub(/INV#/, "", $1); inv_number = $1
  } else {
    error("expected invoice number on line " FNR)
  }
}

function parse_date() {
  if ($2 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/) {
    date = $2
  } else {
    error("expected date on line " FNR)
  }
}

function parse_customer_address() {
  if (NF > 2 && $3 ~ /^[[:alnum:]_].*/) {
    cid = join_fields(3,NF)
    customer_address = find_customer(cid)
  } else {
    error("expected customer name on line " FNR)  
  }
}

function parse_discount(  i) {
  dcnt++
  # look for the amount field
  for (i = 1; i <= NF; i++) {
    if ($i ~ /^-[0-9|\$]/) {
      amt = strip_amount($i)
      discounts[dcnt, "amt"] = amt

      # previous fields are the description
      desc = join_fields(1, i - 1)
      discounts[dcnt, "desc"] = desc

      # done
      return
    }
  }
}

function parse_project() {
  if (proj && prcnt && lcnt == 0) {
    error("expected line item but got new project at line " FNR + 1)
  } else {
    prcnt++
    proj = join_fields(1, NF)
    lcnt = 0
    projects[prcnt, "desc"] = proj
    projects[prcnt, "lcnt"] = 0
  }
}

function parse_line_item(     rate, units, amount, subtotal, desc, desc_stop) {
  if (proj) {
    if ($NF ~ /^[\-]?[\$]?[0-9]/) {
      rate = strip_amount($NF)
    } else {
      error("expected valid amount on line " FNR)
    }

    desc_stop = NF - 1
    if ($(NF - 1) == "@") {
      for (i = (NF - 2); i >= 1; i--) {
        if (match($i, /^[0-9]+[\.]*[0-9]*/)) {
          units = substr($i, RSTART, RLENGTH)
          desc_stop = i - 1
          break
        }
      }
    }

    if (!units) units = 1

    desc = join_fields(1, desc_stop)
      
    lcnt++
    projects[prcnt, "line_items", lcnt, "desc"] = desc
    projects[prcnt, "line_items", lcnt, "rate"] = rate
    projects[prcnt, "line_items", lcnt, "units"] = units
    amount = rate * units
    projects[prcnt, "line_items", lcnt, "amount"] = amount
    subtotal = projects[prcnt, "subtotal"]
    if (!subtotal) subtotal = 0
    projects[prcnt, "subtotal"] = subtotal + amount
    if (!grandtotal) grandtotal = 0
    grandtotal = grandtotal + amount
    projects[prcnt, "lcnt"] = lcnt
  } else {
    error("expected project but got line item on line " FNR)
  }
}

function print_discounts() {
  for (i = 1; i <= dcnt; i++) {
    desc = discounts[i, "desc"]
    amt = discounts[i, "amt"]
    sub(/\-/, "", amt)
    print_discount(desc, amt)
  }
}

function print_projects() {
  for (i = 1; i <= prcnt; i++) {
    print_project(i)
  }
}

function print_project(i,     title, description, rate, units) {
  title = projects[i, "desc"]
  print "      \\multicolumn{5}{c}{\\textbf{\\large{" title "}}}\\\\"
  print "      \\noindent\\textbf{Activity}&& Rate/Unit & Count & Amount\\\\"
  print "      \\hline"

  # print project line items
  for (j = 1; j <= projects[i, "lcnt"]; j++) {
    description = projects[i, "line_items", j, "desc"]  
    rate = projects[i, "line_items", j, "rate"]
    units = projects[i, "line_items", j, "units"]
    amount = projects[i, "line_items", j, "amount"]
    print_line_item(description, rate, units, amount)
  }

  # print project subtotal
  subtotal = projects[i, "subtotal"]
  print "       \\noindent{Subtotal " title "}&& & & {" subtotal "}\\\\"
}

# print discount
function print_discount(description, amount) {
  amount = sprintf("%0.2f", amount/100)
  print "      \\noindent{" description "}&&{" amount "}"
}

# print line item
function print_line_item(description, rate, units, amount) {
  rate = sprintf("%.2f", rate/100)
  amount = sprintf("%.2f", amount/100)
  print "        \\noindent{" description "}&&" rate " & " units " & " amount "\\\\"
}

function address() {
  return (business ? find_customer(business) : customers[1])
}

function after_customer() {
  if (length(customers) == 0)
    error("customer database empty")
}

function after_invoice(   i) {
  for (i = 1; i <= pcnt; i++)
    if (projects[i, "lcnt"] == 0)
      error("project \"" projects[i, "title"] "\" has no line items")
}

function find_customer(c) {
  if (c in cmap) {
    return customers[cmap[c]]
  } else {
    error("customer \"" c "\" not found")
  }
}

function error(s) { errors = "yes"; printf("error: %s\n", s); exit 1 }

function join_fields(start, finish,     s, i) {
  for (i = start; i <= finish; i++) {
    if (s) {
      s = s " " $i
    } else {
      s = $i
    }
  }
  return s
}

function strip_amount(s) {
  sub(/[\$|,]/, "", s)
  sub(/\./, "", s)
  return s
}

function lstrip(s) {
  if (match(s, /^[[:blank:]_]+/)) {
    s = substr(s, RLENGTH, length(s))
  }
  return s
}
