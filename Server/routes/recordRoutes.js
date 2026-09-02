/**
 * Module: Routes
 * Purpose: Keeps existing app search and detailed record endpoints working inside the single backend.
 */
const express = require("express");
const {
  searchData,
  listSearchData,
  listDataWithDetails,
} = require("../utils/recordUtils");

const router = express.Router();

router.all("/searchData", searchData);
router.all("/listSearchData", listSearchData);
router.all("/listDataWithDetails", listDataWithDetails);

module.exports = router;
