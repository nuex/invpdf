invpdf
=======

Generate PDF invoices from text files.

## SYNOPSIS

    invpdf [OPTION]... INVOICE_FILE OUTPUT_FILE

## DEPENDENCIES

LaTeX and the latex-invoice package is required to generate the PDF. Installing
these is usually as easy as installing the texlive-latex-extra package in
Ubuntu or ArchLinux.

## INSTALL

    git clone git://github.com/nuex/invpdf.git
    cd invpdf
    export PATH="$(pwd)/bin:$PATH"
    export INV_AWKLIB="$(pwd)/lib"

## DESCRIPTION

The following command generates a PDF using the passed in customers database
and invoice:

    invpdf -c=example/customers.txt example/0001.txt example/0001.pdf

Setting INV_CUSTOMERS to the customers.txt path to save having to pass that
argument:

    invpdf example/0001.txt example/0001.pdf

## OPTIONS

    -c=<path>
        Set the path to the customer database file. Equivalent to setting the
        INV_CUSTOMERS environment variable.

    -l=<closing>
        Set the closing text for the invoice. Equivalent to setting the
        INV_CLOSING environment variable.

## CUSTOMER FILE

The customers database file will be used to display the customer address in the
exported invoice. The company name is used as a unique ID to reference the
company in an invoice.

Example customer database:

    MYCOMPANY
    Somewhere Dr.
    Boston, MA 10491
    1-800-PAYME

    ACME
    400 Main St.
    New York City, New York 10229

## INVOICE FILE

*Header* - Used to reference the company and set the date of the invoice.

    INV#INV_NUMBER DATE COMPANY_NAME

*Project* - Used to categorize line items. A project's line items must be
indented at least two spaces.

    PROJECT
      LINE ITEM

*Line Item* - Description and amount to add to the invoice. Line items may have
a negative amount. Dollar sign and decimal is optional in the amount.

    DESCRIPTION   AMOUNT

Units are also available:

    DESCRIPTION   UNITS @ AMOUNT

Units must be an integer followed by a unit type with the "@" symbol separating
the unit from the amount. For example: "10h @ $20.00" or "100 bushels @ $10.00".

The description must be separated from the amount or units by at least three
spaces.

*Discounts* - Discounts subtract from the total amount. Unlike line items they
are not nested inside a project.

    DESCRIPTION   AMOUNT

*Comments* - Any lines beginning with a semicolon or any text following a
semicolon will be ignored.

Here is an example invoice:

    ; INVOICE TOTAL: $800.00

    INV#0001 2012-07-02 ACME

    Software Services
      CMS Project          10h @ $70.00 

    IT Services
      Equipment Costs           $100.00
      Installation          1h @ $50.00

    Installation Costs Waived   -$50.00 ; Example discount
