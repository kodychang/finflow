package com.shokoforms.android;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.ActivityNotFoundException;
import android.content.ClipData;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.graphics.pdf.PdfDocument;
import android.net.Uri;
import android.os.Bundle;
import android.provider.OpenableColumns;
import android.text.InputType;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.ScaleGestureDetector;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.HorizontalScrollView;
import android.widget.LinearLayout;
import android.widget.ListView;
import android.widget.ScrollView;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import androidx.activity.ComponentActivity;

import com.android.billingclient.api.AcknowledgePurchaseParams;
import com.android.billingclient.api.BillingClient;
import com.android.billingclient.api.BillingClientStateListener;
import com.android.billingclient.api.BillingFlowParams;
import com.android.billingclient.api.BillingResult;
import com.android.billingclient.api.PendingPurchasesParams;
import com.android.billingclient.api.ProductDetails;
import com.android.billingclient.api.Purchase;
import com.android.billingclient.api.PurchasesUpdatedListener;
import com.android.billingclient.api.QueryProductDetailsParams;
import com.android.billingclient.api.QueryPurchasesParams;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.text.NumberFormat;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

public class MainActivity extends ComponentActivity {
    private static final int REQ_IMPORT_BACKUP = 10;
    private static final int REQ_IMPORT_ATTACHMENT = 11;
    private static final int REQ_CREATE_PDF = 12;
    private static final int REQ_CREATE_BACKUP = 13;
    private static final int REQ_IMPORT_FORM = 14;

    private final Store store = new Store();
    private LinearLayout root;
    private LinearLayout content;
    private View bottomNav;
    private String section = "home";
    private boolean darkMode;
    private boolean proUnlocked;
    private int pendingAttachmentTarget = 0;
    private BusinessDocument pendingPdfDocument;
    private BillingManager billingManager;
    private PreviewCanvas activePreviewCanvas;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        store.load(this);
        SharedPreferences prefs = getSharedPreferences("shoko.android.settings", MODE_PRIVATE);
        darkMode = prefs.getBoolean("darkMode", false);
        proUnlocked = prefs.getBoolean("proUnlocked", false);
        billingManager = new BillingManager(this);
        billingManager.start();
        buildShell();
        showHome();
        handleIncomingIntent(getIntent());
    }

    @Override
    protected void onDestroy() {
        if (billingManager != null) billingManager.destroy();
        super.onDestroy();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleIncomingIntent(intent);
    }

    private void buildShell() {
        root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(0, statusBarInset(), 0, navigationBarInset());
        root.setBackgroundColor(bg());
        getWindow().setStatusBarColor(panel());
        getWindow().setNavigationBarColor(bg());
        setContentView(root);

        root.addView(appBar(), new LinearLayout.LayoutParams(-1, -2));

        content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        root.addView(content, new LinearLayout.LayoutParams(-1, 0, 1));

        bottomNav = bottomNavView();
        root.addView(bottomNav, new LinearLayout.LayoutParams(-1, -2));
    }

    private View appBar() {
        return ComposeBridge.appBar(
            this,
            "Shoko Forms",
            t("androidAppSubtitle"),
            t("support"),
            darkMode,
            accent(),
            () -> showSupportDialog()
        );
    }

    private void redrawShell() {
        getSharedPreferences("shoko.android.settings", MODE_PRIVATE).edit()
            .putBoolean("darkMode", darkMode)
            .putBoolean("proUnlocked", proUnlocked)
            .apply();
        buildShell();
        switch (section) {
            case "create": showEditor(); break;
            case "preview": showPreview(store.current); break;
            case "data": showDataHub(); break;
            case "settings": showSettings(); break;
            default: showHome();
        }
    }

    private void addNav(LinearLayout nav, String title, String target) {
        Button b = button(title);
        b.setTextSize(12);
        b.setTextColor(isNavSelected(target) ? Color.WHITE : muted());
        b.setBackground(rounded(isNavSelected(target) ? accent() : transparentPanel(), dp(18), Color.TRANSPARENT, 0));
        b.setOnClickListener(v -> {
            if ("create".equals(target)) {
                showCreateStart();
            } else if ("preview".equals(target)) {
                showPreview(store.current);
            } else if ("data".equals(target)) {
                showDataHub();
            } else if ("settings".equals(target)) {
                showSettings();
            } else {
                showHome();
            }
        });
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, dp(46), 1);
        lp.setMargins(dp(3), 0, dp(3), 0);
        nav.addView(b, lp);
    }

    private boolean isNavSelected(String target) {
        if ("create".equals(target)) return "create".equals(section);
        if ("preview".equals(target)) return "preview".equals(section);
        if ("data".equals(target)) return "data".equals(section);
        if ("settings".equals(target)) return "settings".equals(section);
        return "home".equals(section);
    }

    private void setSection(String value) {
        section = value;
        content.removeAllViews();
        root.setBackgroundColor(bg());
        refreshBottomNav();
    }

    private void refreshBottomNav() {
        if (root == null || bottomNav == null) return;
        int index = root.indexOfChild(bottomNav);
        root.removeView(bottomNav);
        bottomNav = bottomNavView();
        root.addView(bottomNav, index < 0 ? root.getChildCount() : index, new LinearLayout.LayoutParams(-1, -2));
    }

    private View bottomNavView() {
        return ComposeBridge.bottomNav(
            this,
            selectedNavKey(),
            t("home"),
            t("create"),
            t("preview"),
            t("data"),
            t("settings"),
            darkMode,
            accent(),
            () -> showHome(),
            () -> showCreateStart(),
            () -> showPreview(store.current),
            () -> showDataHub(),
            () -> showSettings()
        );
    }

    private String selectedNavKey() {
        if ("create".equals(section)) return "create";
        if ("preview".equals(section)) return "preview";
        if ("data".equals(section)) return "data";
        if ("settings".equals(section)) return "settings";
        return "home";
    }

    private void showSupportDialog() {
        new AlertDialog.Builder(this)
            .setTitle(t("support"))
            .setMessage(t("supportMessage"))
            .setPositiveButton(t("openGuide"), (dialog, which) -> showOnboardingGuide())
            .setNegativeButton(t("close"), null)
            .show();
    }

    private void showOnboardingGuide() {
        new AlertDialog.Builder(this)
            .setTitle(t("guideTitle"))
            .setMessage(t("guideMessage"))
            .setPositiveButton(t("create"), (dialog, which) -> showCreateStart())
            .setNegativeButton(t("settings"), (dialog, which) -> showSettings())
            .setNeutralButton(t("close"), null)
            .show();
    }

    private void showHome() {
        setSection("home");
        ScrollView scroll = scroll();
        LinearLayout page = page(scroll);
        page.addView(homeHero());

        LinearLayout quick = row();
        quick.addView(action(t("customerForms"), v -> showCreateStartFor(ProjectDirection.CUSTOMER)));
        quick.addView(action(t("vendorForms"), v -> showCreateStartFor(ProjectDirection.VENDOR)));
        page.addView(quick);

        page.addView(sectionTitle(t("recentProjects")));
        List<ProjectArchive> projects = store.projects();
        if (projects.isEmpty()) {
            page.addView(empty(t("noSavedProjects")));
        } else {
            for (int i = 0; i < Math.min(3, projects.size()); i++) {
                ProjectArchive p = projects.get(i);
                page.addView(projectCard(p));
            }
        }

        page.addView(sectionTitle(t("customerForms")));
        addFormPreviewCards(page, ProjectDirection.CUSTOMER);

        page.addView(sectionTitle(t("vendorForms")));
        addFormPreviewCards(page, ProjectDirection.VENDOR);

        page.addView(sectionTitle(t("recentDocuments")));
        if (store.documents.isEmpty()) {
            page.addView(empty(t("noSavedDocuments")));
        } else {
            for (int i = 0; i < Math.min(12, store.documents.size()); i++) {
                BusinessDocument d = store.documents.get(i);
                page.addView(documentCard(d));
            }
        }

        page.addView(sectionTitle(t("management")));
        page.addView(card(t("customers"), v -> showProfileList("customers")));
        page.addView(card(t("products"), v -> showProfileList("products")));
        page.addView(card(t("templates"), v -> showProfileList("templates")));
        page.addView(card(t("company"), v -> showProfileList("issuers")));
    }

    private View homeHero() {
        return ComposeBridge.homeHero(
            this,
            t("documents"),
            t("homeSubtitle"),
            t("documents"),
            store.documents.size(),
            t("projects"),
            store.projects().size(),
            t("customers"),
            store.customers.size(),
            darkMode,
            accent()
        );
    }

    private View metric(String label, String value) {
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(dp(10), dp(8), dp(10), dp(8));
        box.setBackground(rounded(inputBg(), dp(10), Color.TRANSPARENT, 0));
        TextView number = text(value, 20, true);
        TextView caption = text(label, 11, true);
        caption.setTextColor(muted());
        box.addView(number);
        box.addView(caption);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, -2, 1);
        lp.setMargins(0, 0, dp(8), 0);
        box.setLayoutParams(lp);
        return box;
    }

    private void addFormPreviewCards(LinearLayout page, ProjectDirection direction) {
        for (DocumentType type : direction.requiredTypes()) {
            page.addView(card(type.title(store.language) + "\n" + type.subtitle(store.language), v -> {
                store.newDocument(type);
                showEditor();
            }));
        }
    }

    private View projectCard(ProjectArchive p) {
        LinearLayout card = cardBase();
        card.addView(text(p.name == null || p.name.isEmpty() ? t("project") : p.name, 16, true));
        TextView meta = text(p.direction.title(store.language) + "  " + p.completedCount() + "/" + p.direction.requiredTypes().length + "  " + (p.customerName == null || p.customerName.isEmpty() ? t("businessPartner") : p.customerName), 12, true);
        meta.setTextColor(muted());
        card.addView(meta);
        card.setOnClickListener(v -> showProject(p));
        return card;
    }

    private View documentCard(BusinessDocument d) {
        LinearLayout card = cardBase();
        TextView title = text((d.number.isEmpty() ? d.type.title(store.language) : d.number) + "  " + d.type.title(store.language), 16, true);
        card.addView(title);
        card.addView(text(d.customerName.isEmpty() ? "-" : d.customerName, 13, false));
        card.addView(text(money(d.displayTotal()), 13, true));
        card.setOnClickListener(v -> showDocumentActions(d));
        return card;
    }

    private void showDocumentActions(BusinessDocument d) {
        String[] actions = {t("edit"), t("preview"), t("duplicate"), t("delete")};
        new AlertDialog.Builder(this)
            .setTitle(d.type.title(store.language))
            .setItems(actions, (dialog, which) -> {
                if (which == 0) {
                    store.current = d.copy();
                    store.hasActiveDocument = true;
                    showEditor();
                } else if (which == 1) {
                    showPreview(d);
                } else if (which == 2) {
                    store.duplicate(d);
                    toast(t("saved"));
                    showHome();
                } else {
                    confirm(t("deleteConfirm"), () -> {
                        store.delete(d.id);
                        store.save(this);
                        showHome();
                    });
                }
            }).show();
    }

    private void chooseType(ProjectDirection direction) {
        DocumentType[] types = direction.requiredTypes();
        String[] names = new String[types.length];
        for (int i = 0; i < types.length; i++) names[i] = types[i].title(store.language);
        new AlertDialog.Builder(this)
            .setTitle(direction.title(store.language))
            .setItems(names, (d, which) -> {
                store.newDocument(types[which]);
                showEditor();
            }).show();
    }

    private void showCreateStart() {
        showCreateStartFor(null);
    }

    private void showCreateStartFor(ProjectDirection onlyDirection) {
        setSection("create");
        ScrollView scroll = scroll();
        LinearLayout page = page(scroll);
        page.addView(title(t("create")));

        if (onlyDirection == null || onlyDirection == ProjectDirection.CUSTOMER) {
            page.addView(sectionTitle(t("customerForms")));
            addFormPreviewCards(page, ProjectDirection.CUSTOMER);
        }
        if (onlyDirection == null || onlyDirection == ProjectDirection.VENDOR) {
            page.addView(sectionTitle(t("vendorForms")));
            addFormPreviewCards(page, ProjectDirection.VENDOR);
        }
        if (onlyDirection != null) {
            page.addView(button(t("showAllForms"), v -> showCreateStart()));
        }
    }

    private void showEditor() {
        setSection("create");
        store.hasActiveDocument = true;
        BusinessDocument d = store.current;
        ScrollView scroll = scroll();
        LinearLayout page = page(scroll);

        LinearLayout header = row();
        TextView h = title(d.type.title(store.language));
        header.addView(h, new LinearLayout.LayoutParams(0, -2, 1));
        header.addView(button(t("save"), v -> {
            readForm(page, d);
            store.saveCurrent(this);
            toast(t("saveComplete"));
            showEditor();
        }));
        page.addView(header);

        DocumentType[] editableTypes = DocumentType.visibleValues();
        int selectedTypeIndex = 0;
        for (int i = 0; i < editableTypes.length; i++) if (editableTypes[i] == d.type) selectedTypeIndex = i;
        addSpinner(page, t("documents"), selectedTypeIndex, DocumentType.titles(store.language), pos -> {
            readForm(page, d);
            d.type = editableTypes[pos];
            showEditor();
        });
        addTwoInputs(page, "number", t("number"), d.number, "relatedNumber", t("relatedNumber"), d.relatedNumber);
        addTwoInputs(page, "issueDate", t("issueDate"), date(d.issueDate), "transactionDate", t("transactionDate"), date(d.transactionDate));
        if (d.type.showsDueDate()) addTwoInputs(page, "dueDate", t("dueDate"), date(d.dueDate), "projectName", t("project"), safe(d.projectName));
        else addInput(page, "projectName", t("project"), safe(d.projectName));

        if (!d.type.isAttachmentRecord()) {
            page.addView(sectionTitle(t("businessPartner")));
            addInput(page, "customerName", t("customerName"), d.customerName);
            addTwoInputs(page, "customerContact", t("contact"), d.customerContact, "customerPhone", t("phone"), safe(d.customerPhone));
            addInput(page, "customerEmail", t("email"), safe(d.customerEmail));
            addMulti(page, "customerAddress", t("address"), d.customerAddress);

            page.addView(sectionTitle(t("issuer")));
            addInput(page, "issuerName", t("issuerName"), d.issuerName);
            if (d.type.showsIssuerRegistration()) addTwoInputs(page, "issuerRegistration", t("registration"), d.issuerRegistration, "issuerContact", t("contact"), d.issuerContact);
            else addInput(page, "issuerContact", t("contact"), d.issuerContact);
            addInput(page, "issuerPhone", t("phone"), d.issuerPhone);
            addInput(page, "issuerEmail", t("email"), d.issuerEmail);
            addMulti(page, "issuerAddress", t("address"), d.issuerAddress);
        }

        page.addView(sectionTitle(t("lineItems")));
        LinearLayout linesBox = new LinearLayout(this);
        linesBox.setOrientation(LinearLayout.VERTICAL);
        linesBox.setTag("lines");
        page.addView(linesBox);
        for (LineItem line : d.lines) addLineEditor(linesBox, line);
        page.addView(button(t("addLine"), v -> {
            readForm(page, d);
            d.lines.add(new LineItem());
            showEditor();
        }));

        if (!d.type.isAttachmentRecord()) {
            page.addView(sectionTitle(t("notes")));
            addMulti(page, "notes", t("notes"), d.notes);
            if (d.type.showsPaymentDetails()) addMulti(page, "paymentDetails", t("paymentDetails"), d.paymentDetails);
            addMulti(page, "documentMemo", t("terms"), d.documentMemo);
        } else {
            page.addView(sectionTitle(t("attachments")));
            page.addView(text(t("attachments") + ": " + d.orderAttachments.size(), 14, true));
            page.addView(button(t("addAttachment"), v -> openAttachmentPicker(1)));
        }

        if (d.type.isVendorForm()) {
            page.addView(sectionTitle(t("paymentProof")));
            addInput(page, "paymentProofDate", t("paymentDate"), date(d.paymentProofDate == 0 ? new Date().getTime() : d.paymentProofDate));
            addInput(page, "paymentProofAmount", t("paymentAmount"), String.valueOf(d.paymentProofAmount));
            page.addView(text(t("attachments") + ": " + d.paymentProofAttachments.size(), 14, true));
            page.addView(button(t("addAttachment"), v -> openAttachmentPicker(2)));
        }

        LinearLayout actions = row();
        actions.addView(button(t("preview"), v -> {
            readForm(page, d);
            store.saveCurrent(this);
            showPreview(d);
        }));
        actions.addView(button(t("duplicate"), v -> {
            readForm(page, d);
            store.saveCurrent(this);
            store.duplicate(d);
            showEditor();
        }));
        actions.addView(button(t("delete"), v -> confirm(t("deleteConfirm"), () -> {
            store.delete(d.id);
            store.save(this);
            showHome();
        })));
        page.addView(actions);
    }

    private void addLineEditor(LinearLayout box, LineItem line) {
        LinearLayout card = cardBase();
        card.setTag(line.id);
        addInput(card, "lineName", t("itemName"), line.name);
        addTwoInputs(card, "lineModel", t("model"), line.model, "lineSpec", t("specification"), line.specification);
        addTwoInputs(card, "lineQty", t("quantity"), trim(line.quantity), "linePrice", t("unitPrice"), trim(line.unitPrice));
        card.addView(button(t("rememberProduct"), v -> {
            readForm((ViewGroup) content.getChildAt(0), store.current);
            store.rememberProduct(line);
            store.save(this);
            toast(t("saved"));
        }));
        card.addView(button(t("delete"), v -> {
            store.current.lines.remove(line);
            if (store.current.lines.isEmpty()) store.current.lines.add(new LineItem());
            showEditor();
        }));
        box.addView(card);
    }

    private void readForm(ViewGroup page, BusinessDocument d) {
        Map<String, List<String>> values = collectInputs(page);
        d.number = first(values, "number", d.number);
        d.relatedNumber = first(values, "relatedNumber", d.relatedNumber);
        d.issueDate = parseDate(first(values, "issueDate", date(d.issueDate)));
        d.transactionDate = parseDate(first(values, "transactionDate", date(d.transactionDate)));
        d.dueDate = parseDate(first(values, "dueDate", date(d.dueDate)));
        d.projectName = first(values, "projectName", safe(d.projectName));
        d.customerName = first(values, "customerName", d.customerName);
        d.customerContact = first(values, "customerContact", d.customerContact);
        d.customerPhone = first(values, "customerPhone", safe(d.customerPhone));
        d.customerEmail = first(values, "customerEmail", safe(d.customerEmail));
        d.customerAddress = first(values, "customerAddress", d.customerAddress);
        d.issuerName = first(values, "issuerName", d.issuerName);
        d.issuerRegistration = first(values, "issuerRegistration", d.issuerRegistration);
        d.issuerContact = first(values, "issuerContact", d.issuerContact);
        d.issuerPhone = first(values, "issuerPhone", d.issuerPhone);
        d.issuerEmail = first(values, "issuerEmail", d.issuerEmail);
        d.issuerAddress = first(values, "issuerAddress", d.issuerAddress);
        d.notes = first(values, "notes", d.notes);
        d.paymentDetails = first(values, "paymentDetails", d.paymentDetails);
        d.documentMemo = first(values, "documentMemo", d.documentMemo);
        d.paymentProofDate = parseDate(first(values, "paymentProofDate", date(d.paymentProofDate)));
        d.paymentProofAmount = parseDouble(first(values, "paymentProofAmount", String.valueOf(d.paymentProofAmount)));

        List<String> names = values.get("lineName");
        List<String> models = values.get("lineModel");
        List<String> specs = values.get("lineSpec");
        List<String> qty = values.get("lineQty");
        List<String> price = values.get("linePrice");
        if (names != null) {
            ArrayList<LineItem> lines = new ArrayList<>();
            for (int i = 0; i < names.size(); i++) {
                LineItem line = i < d.lines.size() ? d.lines.get(i) : new LineItem();
                line.name = names.get(i);
                line.model = get(models, i);
                line.specification = get(specs, i);
                line.quantity = parseDouble(get(qty, i), 1);
                line.unitPrice = parseDouble(get(price, i), 0);
                lines.add(line);
            }
            if (lines.isEmpty()) lines.add(new LineItem());
            d.lines = lines;
        }
    }

    private Map<String, List<String>> collectInputs(View view) {
        Map<String, List<String>> map = new HashMap<>();
        if (view instanceof EditText && view.getTag() instanceof String) {
            String key = (String) view.getTag();
            List<String> list = map.get(key);
            if (list == null) {
                list = new ArrayList<>();
                map.put(key, list);
            }
            list.add(((EditText) view).getText().toString());
        }
        if (view instanceof ViewGroup) {
            ViewGroup group = (ViewGroup) view;
            for (int i = 0; i < group.getChildCount(); i++) {
                Map<String, List<String>> child = collectInputs(group.getChildAt(i));
                for (String key : child.keySet()) {
                    List<String> list = map.get(key);
                    if (list == null) {
                        list = new ArrayList<>();
                        map.put(key, list);
                    }
                    list.addAll(child.get(key));
                }
            }
        }
        return map;
    }

    private void showPreview(BusinessDocument d) {
        setSection("preview");
        BusinessDocument doc = d == null ? store.current : d;
        LinearLayout screen = new LinearLayout(this);
        screen.setOrientation(LinearLayout.VERTICAL);
        screen.setBackgroundColor(bg());
        content.addView(screen, new LinearLayout.LayoutParams(-1, -1));

        LinearLayout bar = new LinearLayout(this);
        bar.setOrientation(LinearLayout.VERTICAL);
        bar.setPadding(dp(12), dp(8), dp(12), dp(10));
        bar.setBackgroundColor(panel());

        LinearLayout top = row();
        TextView label = text(t("pdfPreview"), 16, true);
        top.addView(label, new LinearLayout.LayoutParams(0, -2, 1));
        top.addView(button(t("savePDF"), v -> exportPdf(doc, false)));
        top.addView(button(t("share"), v -> {
            if (requirePro("proShareMessage")) exportPdf(doc, true);
        }));
        bar.addView(top);

        TextView meta = text((doc.number.isEmpty() ? doc.type.title(store.language) : doc.number) + "  A4 PDF", 12, true);
        meta.setTextColor(muted());
        bar.addView(meta);

        LinearLayout zoom = row();
        zoom.setPadding(0, dp(8), 0, 0);
        zoom.addView(button(t("zoomOut"), v -> {
            if (activePreviewCanvas != null) activePreviewCanvas.adjustZoom(0.9f);
        }), new LinearLayout.LayoutParams(0, dp(42), 1));
        zoom.addView(button(t("fitWidth"), v -> {
            if (activePreviewCanvas != null) activePreviewCanvas.fitWidth();
        }), new LinearLayout.LayoutParams(0, dp(42), 1));
        zoom.addView(button(t("zoomIn"), v -> {
            if (activePreviewCanvas != null) activePreviewCanvas.adjustZoom(1.1f);
        }), new LinearLayout.LayoutParams(0, dp(42), 1));
        bar.addView(zoom);
        screen.addView(bar);

        HorizontalScrollView horizontal = new HorizontalScrollView(this);
        horizontal.setFillViewport(true);
        horizontal.setBackgroundColor(bg());
        ScrollView vertical = new ScrollView(this);
        vertical.setFillViewport(true);
        vertical.setBackgroundColor(bg());
        FrameLayout pageStage = new FrameLayout(this);
        pageStage.setPadding(dp(10), dp(14), dp(10), dp(28));
        pageStage.setBackgroundColor(bg());
        PreviewCanvas preview = new PreviewCanvas(this);
        preview.document = doc;
        preview.language = store.pdfLanguage;
        int availableWidth = Math.max(dp(280), getResources().getDisplayMetrics().widthPixels - dp(44));
        preview.configure(availableWidth, horizontal, vertical);
        activePreviewCanvas = preview;
        pageStage.addView(preview);
        vertical.addView(pageStage);
        horizontal.addView(vertical);
        screen.addView(horizontal, new LinearLayout.LayoutParams(-1, 0, 1));
    }

    private void showDataHub() {
        setSection("data");
        ScrollView scroll = scroll();
        LinearLayout page = page(scroll);
        page.addView(title(t("data")));
        page.addView(card(t("projects"), v -> showProjects()));
        page.addView(card(t("deletedFiles"), v -> showDeletedFiles()));
        page.addView(card(t("customers"), v -> showProfileList("customers")));
        page.addView(card(t("products"), v -> showProfileList("products")));
        page.addView(card(t("templates"), v -> showProfileList("templates")));
        page.addView(card(t("company"), v -> showProfileList("issuers")));
        page.addView(card(t("exportBackup"), v -> exportBackup()));
        page.addView(card(t("importBackup"), v -> openJson(REQ_IMPORT_BACKUP)));
        page.addView(card(t("importForm"), v -> openJson(REQ_IMPORT_FORM)));
        page.addView(card(t("clearData"), v -> confirm(t("clearDataConfirm"), () -> {
            store.clear();
            store.save(this);
            showDataHub();
        })));
    }

    private void showDeletedFiles() {
        setSection("data");
        store.pruneDeletedDocuments();
        ScrollView scroll = scroll();
        LinearLayout page = page(scroll);
        page.addView(title(t("deletedFiles")));
        page.addView(empty(t("deleteHistoryMessage")));
        if (store.deletedDocuments.isEmpty()) {
            page.addView(empty(t("noDeletedFiles")));
            return;
        }
        for (DeletedDocumentRecord record : store.deletedDocuments) {
            BusinessDocument d = record.document;
            LinearLayout card = cardBase();
            card.addView(text((d.number.isEmpty() ? d.type.title(store.language) : d.number) + "  " + d.type.title(store.language), 16, true));
            card.addView(text((d.customerName.isEmpty() ? "-" : d.customerName) + "  " + money(d.displayTotal()), 13, false));
            TextView dates = text(t("deletedAt") + " " + date(record.deletedAt) + "  " + t("expiresAt") + " " + date(record.expiresAt()), 12, true);
            dates.setTextColor(muted());
            card.addView(dates);
            LinearLayout actions = row();
            actions.addView(button(t("restore"), v -> {
                store.restoreDeleted(record.id);
                store.save(this);
                toast(t("documentRestoreComplete"));
                showDeletedFiles();
            }), new LinearLayout.LayoutParams(0, dp(44), 1));
            actions.addView(button(t("permanentDelete"), v -> confirm(t("permanentDeleteConfirm"), () -> {
                store.permanentlyDeleteDeleted(record.id);
                store.save(this);
                showDeletedFiles();
            })), new LinearLayout.LayoutParams(0, dp(44), 1));
            card.addView(actions);
            page.addView(card);
        }
    }

    private void showProjects() {
        setSection("data");
        ScrollView scroll = scroll();
        LinearLayout page = page(scroll);
        page.addView(title(t("projects")));
        page.addView(button(t("newCustomerProject"), v -> createProject(ProjectDirection.CUSTOMER)));
        page.addView(button(t("newVendorProject"), v -> createProject(ProjectDirection.VENDOR)));
        for (ProjectArchive p : store.projects()) page.addView(card(p.name + "\n" + p.direction.title(store.language), v -> showProject(p)));
    }

    private void showProject(ProjectArchive project) {
        setSection("data");
        ScrollView scroll = scroll();
        LinearLayout page = page(scroll);
        page.addView(title(project.name));
        page.addView(text(project.direction.title(store.language) + "  " + project.completedCount() + "/" + project.direction.requiredTypes().length, 14, true));
        for (DocumentType type : project.direction.requiredTypes()) {
            BusinessDocument existing = project.document(type);
            page.addView(card(type.title(store.language) + "\n" + (existing == null ? t("create") : existing.number), v -> {
                if (existing != null) {
                    store.current = existing.copy();
                    store.hasActiveDocument = true;
                } else {
                    store.newDocument(type);
                    store.current.projectId = project.id;
                    store.current.projectName = project.name;
                    store.current.projectDirection = project.direction.name();
                    store.current.customerName = project.customerName;
                    store.saveCurrent(this);
                }
                showEditor();
            }));
        }
        page.addView(button(t("delete"), v -> confirm(t("deleteConfirm"), () -> {
            store.deleteProject(project.id);
            store.save(this);
            showProjects();
        })));
    }

    private void createProject(ProjectDirection direction) {
        BusinessDocument d = store.newDocument(direction.firstType());
        d.projectId = UUID.randomUUID().toString();
        d.projectDirection = direction.name();
        d.projectName = direction.title(store.language) + " " + date(System.currentTimeMillis());
        store.saveCurrent(this);
        showProject(store.projects().get(0));
    }

    private void handleIncomingIntent(Intent intent) {
        if (intent == null) return;
        String action = intent.getAction();
        ArrayList<Uri> attachmentUris = new ArrayList<>();
        if (Intent.ACTION_SEND.equals(action)) {
            Uri stream = intent.getParcelableExtra(Intent.EXTRA_STREAM);
            if (stream != null) attachmentUris.add(stream);
        } else if (Intent.ACTION_SEND_MULTIPLE.equals(action)) {
            ArrayList<Uri> streams = intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM);
            if (streams != null) attachmentUris.addAll(streams);
        } else if (intent.getData() != null) {
            Uri data = intent.getData();
            if (isExternalAttachmentUri(data)) {
                attachmentUris.add(data);
            } else {
                importUri(data, true);
            }
        }
        if (!attachmentUris.isEmpty()) {
            showExternalAttachmentImport(normalizeExternalAttachmentUris(attachmentUris));
            intent.setData(null);
            intent.removeExtra(Intent.EXTRA_STREAM);
        }
    }

    private ArrayList<Uri> normalizeExternalAttachmentUris(ArrayList<Uri> uris) {
        ArrayList<Uri> supported = new ArrayList<>();
        Uri pdf = null;
        for (Uri uri : uris) {
            if (!isExternalAttachmentUri(uri)) continue;
            if (isPdfUri(uri)) {
                if (pdf == null) pdf = uri;
            } else {
                supported.add(uri);
            }
        }
        if (pdf != null) {
            if (uris.size() > 1) toast(t("pdfSingleOnly"));
            supported.clear();
            supported.add(pdf);
        }
        return supported;
    }

    private boolean isExternalAttachmentUri(Uri uri) {
        String type = getContentResolver().getType(uri);
        if (type != null && (type.startsWith("image/") || "application/pdf".equals(type))) return true;
        String name = displayName(uri).toLowerCase(Locale.US);
        return name.endsWith(".pdf") || name.endsWith(".png") || name.endsWith(".jpg") || name.endsWith(".jpeg") || name.endsWith(".webp") || name.endsWith(".gif");
    }

    private boolean isPdfUri(Uri uri) {
        String type = getContentResolver().getType(uri);
        if ("application/pdf".equals(type)) return true;
        return displayName(uri).toLowerCase(Locale.US).endsWith(".pdf");
    }

    private void showExternalAttachmentImport(ArrayList<Uri> uris) {
        if (uris.isEmpty()) {
            toast(t("importError"));
            return;
        }
        String[] labels = {ProjectDirection.CUSTOMER.title(store.language), ProjectDirection.VENDOR.title(store.language)};
        new AlertDialog.Builder(this)
            .setTitle(t("externalImportTitle"))
            .setMessage(t("externalImportMessage"))
            .setItems(labels, (dialog, which) -> {
                ProjectDirection direction = which == 1 ? ProjectDirection.VENDOR : ProjectDirection.CUSTOMER;
                chooseExternalImportProject(uris, direction);
            })
            .setNegativeButton(t("cancel"), null)
            .show();
    }

    private void chooseExternalImportProject(ArrayList<Uri> uris, ProjectDirection direction) {
        List<ProjectArchive> projects = new ArrayList<>();
        for (ProjectArchive project : store.projects()) {
            if (project.direction == direction) projects.add(project);
        }
        ArrayList<String> labels = new ArrayList<>();
        labels.add(t("newProject"));
        for (ProjectArchive project : projects) labels.add(project.name);
        new AlertDialog.Builder(this)
            .setTitle(t("externalImportProject"))
            .setItems(labels.toArray(new String[0]), (dialog, which) -> {
                ProjectArchive project = which == 0 ? null : projects.get(which - 1);
                chooseExternalImportType(uris, direction, project);
            })
            .setNegativeButton(t("cancel"), null)
            .show();
    }

    private void chooseExternalImportType(ArrayList<Uri> uris, ProjectDirection direction, ProjectArchive project) {
        DocumentType[] types = direction == ProjectDirection.VENDOR
            ? new DocumentType[]{DocumentType.VENDOR_ESTIMATE, DocumentType.VENDOR_INVOICE, DocumentType.VENDOR_RECEIPT}
            : new DocumentType[]{DocumentType.CUSTOMER_ORDER};
        String[] labels = new String[types.length];
        for (int i = 0; i < types.length; i++) labels[i] = types[i].title(store.language);
        new AlertDialog.Builder(this)
            .setTitle(t("externalImportForm"))
            .setItems(labels, (dialog, which) -> importExternalAttachments(uris, direction, project, types[which]))
            .setNegativeButton(t("cancel"), null)
            .show();
    }

    private void importExternalAttachments(ArrayList<Uri> uris, ProjectDirection direction, ProjectArchive project, DocumentType type) {
        try {
            openProjectAttachmentForm(direction, project, type);
            for (Uri uri : uris) store.current.orderAttachments.add(readAttachment(uri));
            store.saveCurrent(this);
            showEditor();
            toast(t("externalImportDone"));
        } catch (Exception e) {
            toast(t("importError") + " " + e.getMessage());
        }
    }

    private void openProjectAttachmentForm(ProjectDirection direction, ProjectArchive project, DocumentType type) {
        if (project != null) {
            BusinessDocument existing = project.document(type);
            if (existing != null) {
                store.current = existing.copy();
                store.hasActiveDocument = true;
                if (store.current.orderAttachments == null) store.current.orderAttachments = new ArrayList<>();
                return;
            }
            BusinessDocument document = store.newDocument(type);
            document.projectId = project.id;
            document.projectName = project.name;
            document.projectDirection = direction.name();
            document.customerName = project.customerName;
            return;
        }
        BusinessDocument document = store.newDocument(type);
        document.projectId = UUID.randomUUID().toString();
        document.projectDirection = direction.name();
        document.projectName = direction.title(store.language) + " " + date(System.currentTimeMillis());
    }

    private void showProfileList(String kind) {
        setSection("data");
        ScrollView scroll = scroll();
        LinearLayout page = page(scroll);
        page.addView(title(t(kind)));
        page.addView(button(t("add"), v -> editProfile(kind, null)));
        if ("customers".equals(kind)) {
            for (CustomerProfile p : store.customers) page.addView(card(p.name + "\n" + p.contact, v -> editProfile(kind, p.id)));
        } else if ("issuers".equals(kind)) {
            for (IssuerProfile p : store.issuers) page.addView(card(p.name + "\n" + p.registration, v -> editProfile(kind, p.id)));
        } else if ("products".equals(kind)) {
            for (ProductProfile p : store.products) page.addView(card(p.name + "\n" + money(p.unitPrice), v -> editProfile(kind, p.id)));
        } else {
            for (TextTemplate p : store.templates) page.addView(card(p.title + "\n" + p.kind, v -> editProfile(kind, p.id)));
        }
    }

    private void editProfile(String kind, String id) {
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(dp(12), dp(8), dp(12), dp(4));
        if ("customers".equals(kind)) {
            CustomerProfile p = store.findCustomer(id);
            addInput(box, "name", t("name"), p.name);
            addInput(box, "contact", t("contact"), p.contact);
            addInput(box, "phone", t("phone"), p.phone);
            addInput(box, "email", t("email"), p.email);
            addMulti(box, "address", t("address"), p.address);
        } else if ("issuers".equals(kind)) {
            IssuerProfile p = store.findIssuer(id);
            addInput(box, "name", t("name"), p.name);
            addInput(box, "registration", t("registration"), p.registration);
            addInput(box, "contact", t("contact"), p.contact);
            addInput(box, "phone", t("phone"), p.phone);
            addInput(box, "email", t("email"), p.email);
            addMulti(box, "address", t("address"), p.address);
        } else if ("products".equals(kind)) {
            ProductProfile p = store.findProduct(id);
            addInput(box, "name", t("name"), p.name);
            addInput(box, "model", t("model"), p.model);
            addInput(box, "specification", t("specification"), p.specification);
            addInput(box, "unitPrice", t("unitPrice"), trim(p.unitPrice));
        } else {
            TextTemplate p = store.findTemplate(id);
            addInput(box, "title", t("title"), p.title);
            addInput(box, "kind", t("type"), p.kind);
            addMulti(box, "content", t("content"), p.content);
        }
        new AlertDialog.Builder(this)
            .setTitle(t("save"))
            .setView(box)
            .setPositiveButton(t("save"), (dialog, which) -> {
                Map<String, List<String>> values = collectInputs(box);
                saveProfileWithRiskCheck(kind, id, values);
            })
            .setNegativeButton(t("cancel"), null)
            .setNeutralButton(t("delete"), (dialog, which) -> {
                deleteProfileWithRiskCheck(kind, id);
            }).show();
    }

    private void saveProfileWithRiskCheck(String kind, String id, Map<String, List<String>> values) {
        int usage = store.profileUsageCount(kind, id);
        if (id != null && usage > 0 && ("customers".equals(kind) || "products".equals(kind))) {
            new AlertDialog.Builder(this)
                .setTitle(t("profileUsedTitle"))
                .setMessage(t("profileUsedSaveMessage").replace("{count}", String.valueOf(usage)))
                .setPositiveButton(t("updateExisting"), (d, w) -> {
                    store.upsertProfile(kind, id, values);
                    store.save(this);
                    showProfileList(kind);
                })
                .setNegativeButton(t("cancel"), null)
                .show();
            return;
        }
        store.upsertProfile(kind, id, values);
        store.save(this);
        showProfileList(kind);
    }

    private void deleteProfileWithRiskCheck(String kind, String id) {
        int usage = store.profileUsageCount(kind, id);
        if (id != null && usage > 0 && ("customers".equals(kind) || "products".equals(kind))) {
            new AlertDialog.Builder(this)
                .setTitle(t("profileUsedTitle"))
                .setMessage(t("profileUsedDeleteMessage").replace("{count}", String.valueOf(usage)))
                .setPositiveButton(t("delete"), (d, w) -> {
                    store.deleteProfile(kind, id);
                    store.save(this);
                    showProfileList(kind);
                })
                .setNegativeButton(t("cancel"), null)
                .show();
            return;
        }
        store.deleteProfile(kind, id);
        store.save(this);
        showProfileList(kind);
    }

    private void showSettings() {
        setSection("settings");
        ScrollView scroll = scroll();
        LinearLayout page = page(scroll);
        page.addView(title(t("settings")));
        addSpinner(page, t("interfaceLanguage"), store.language.ordinal(), AppLanguage.names(), pos -> {
            store.language = AppLanguage.values()[pos];
            store.save(this);
            redrawShell();
        });
        addSpinner(page, t("pdfLanguage"), store.pdfLanguage.ordinal(), AppLanguage.names(), pos -> {
            store.pdfLanguage = AppLanguage.values()[pos];
            store.save(this);
            redrawShell();
        });
        CheckBox dark = new CheckBox(this);
        dark.setText(t("darkMode"));
        dark.setTextColor(ink());
        dark.setChecked(darkMode);
        dark.setOnCheckedChangeListener((buttonView, isChecked) -> {
            darkMode = isChecked;
            redrawShell();
        });
        page.addView(dark);
        addSpinner(page, t("tableColor"), store.defaultColor.ordinal(), ColorTemplate.names(), pos -> {
            store.defaultColor = ColorTemplate.values()[pos];
            store.current.colorTemplate = store.defaultColor;
            store.save(this);
        });
        page.addView(sectionTitle(t("proPlan")));
        page.addView(text(proUnlocked ? t("proActive") : t("proInactive"), 14, true));
        String monthlyLabel = t("buyMonthly");
        String yearlyLabel = t("buyYearly");
        if (billingManager != null) {
            String monthlyPrice = billingManager.priceFor(BillingManager.MONTHLY_PRODUCT_ID);
            String yearlyPrice = billingManager.priceFor(BillingManager.YEARLY_PRODUCT_ID);
            if (!monthlyPrice.isEmpty()) monthlyLabel += "  " + monthlyPrice;
            if (!yearlyPrice.isEmpty()) yearlyLabel += "  " + yearlyPrice;
        }
        page.addView(button(monthlyLabel, v -> purchasePro(BillingManager.MONTHLY_PRODUCT_ID)));
        page.addView(button(yearlyLabel, v -> purchasePro(BillingManager.YEARLY_PRODUCT_ID)));
        page.addView(button(t("restorePurchases"), v -> restorePurchases()));
        page.addView(text(t("androidBillingNote"), 13, false));
    }

    private void purchasePro(String productId) {
        if (billingManager == null) return;
        billingManager.purchase(productId);
    }

    private void restorePurchases() {
        if (billingManager == null) return;
        billingManager.restorePurchases();
    }

    private void setProUnlocked(boolean unlocked, String statusKey) {
        proUnlocked = unlocked;
        getSharedPreferences("shoko.android.settings", MODE_PRIVATE).edit().putBoolean("proUnlocked", proUnlocked).apply();
        if (statusKey != null) toast(t(statusKey));
        if ("settings".equals(section)) showSettings();
    }

    private boolean requirePro(String featureKey) {
        if (proUnlocked) return true;
        new AlertDialog.Builder(this)
            .setTitle(t("proRequiredTitle"))
            .setMessage(t(featureKey))
            .setPositiveButton(t("openPro"), (dialog, which) -> showSettings())
            .setNegativeButton(t("cancel"), null)
            .show();
        return false;
    }

    private void openAttachmentPicker(int target) {
        pendingAttachmentTarget = target;
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("*/*");
        intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
        startActivityForResult(intent, REQ_IMPORT_ATTACHMENT);
    }

    private void openJson(int request) {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("*/*");
        startActivityForResult(intent, request);
    }

    private void exportBackup() {
        Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("application/json");
        intent.putExtra(Intent.EXTRA_TITLE, "shoko-forms-backup-" + new SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(new Date()) + ".shokobackup");
        startActivityForResult(intent, REQ_CREATE_BACKUP);
    }

    private void exportPdf(BusinessDocument document, boolean share) {
        pendingPdfDocument = document;
        if (share) {
            try {
                File file = new File(getCacheDir(), fileBase(document) + ".pdf");
                writePdf(document, Uri.fromFile(file));
                allowFileUriShare();
                Intent intent = new Intent(Intent.ACTION_SEND);
                intent.setType("application/pdf");
                intent.putExtra(Intent.EXTRA_STREAM, Uri.fromFile(file));
                startActivity(Intent.createChooser(intent, t("share")));
            } catch (Exception e) {
                toast(t("pdfExportError") + " " + e.getMessage());
            }
        } else {
            Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.setType("application/pdf");
            intent.putExtra(Intent.EXTRA_TITLE, fileBase(document) + ".pdf");
            startActivityForResult(intent, REQ_CREATE_PDF);
        }
    }

    private void allowFileUriShare() {
        try {
            Class.forName("android.os.StrictMode")
                .getMethod("disableDeathOnFileUriExposure")
                .invoke(null);
        } catch (Exception ignored) {}
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (resultCode != RESULT_OK || data == null) return;
        try {
            if (requestCode == REQ_IMPORT_ATTACHMENT) {
                importAttachments(data);
                store.save(this);
                showEditor();
            } else if (requestCode == REQ_CREATE_PDF && data.getData() != null && pendingPdfDocument != null) {
                writePdf(pendingPdfDocument, data.getData());
                toast(t("saved"));
            } else if (requestCode == REQ_CREATE_BACKUP && data.getData() != null) {
                writeString(data.getData(), store.toJson().toString());
                toast(t("saved"));
            } else if ((requestCode == REQ_IMPORT_BACKUP || requestCode == REQ_IMPORT_FORM) && data.getData() != null) {
                importUri(data.getData(), requestCode == REQ_IMPORT_FORM);
                showDataHub();
            }
        } catch (Exception e) {
            toast(e.getMessage());
        }
    }

    private void importAttachments(Intent data) throws Exception {
        ArrayList<OrderAttachment> attachments = new ArrayList<>();
        if (data.getClipData() != null) {
            ClipData clip = data.getClipData();
            for (int i = 0; i < clip.getItemCount(); i++) attachments.add(readAttachment(clip.getItemAt(i).getUri()));
        } else if (data.getData() != null) {
            attachments.add(readAttachment(data.getData()));
        }
        if (pendingAttachmentTarget == 2) store.current.paymentProofAttachments.addAll(attachments);
        else store.current.orderAttachments.addAll(attachments);
    }

    private OrderAttachment readAttachment(Uri uri) throws Exception {
        OrderAttachment a = new OrderAttachment();
        a.filename = displayName(uri);
        a.contentType = getContentResolver().getType(uri);
        InputStream in = getContentResolver().openInputStream(uri);
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        byte[] buffer = new byte[8192];
        int read;
        while (in != null && (read = in.read(buffer)) != -1) out.write(buffer, 0, read);
        if (in != null) in.close();
        a.bytes = out.toByteArray();
        return a;
    }

    private void importUri(Uri uri, boolean singleForm) {
        try {
            String json = readString(uri);
            JSONObject object = new JSONObject(json);
            if (singleForm || object.has("document")) {
                BusinessDocument d = object.has("document") ? BusinessDocument.fromJson(object.getJSONObject("document")) : BusinessDocument.fromJson(object);
                store.current = d;
                store.saveCurrent(this);
            } else {
                store.fromJson(object);
                store.save(this);
            }
            toast(t("saved"));
        } catch (Exception e) {
            toast(t("importError") + " " + e.getMessage());
        }
    }

    private void writePdf(BusinessDocument d, Uri uri) throws Exception {
        PdfDocument pdf = new PdfDocument();
        PdfDocument.PageInfo info = new PdfDocument.PageInfo.Builder(595, 842, 1).create();
        PdfDocument.Page page = pdf.startPage(info);
        PdfRenderer.draw(page.getCanvas(), d, store.pdfLanguage, 595, 842, 1f);
        pdf.finishPage(page);
        OutputStream out = "file".equals(uri.getScheme()) ? new FileOutputStream(new File(uri.getPath())) : getContentResolver().openOutputStream(uri);
        pdf.writeTo(out);
        if (out != null) out.close();
        pdf.close();
    }

    private void writeString(Uri uri, String value) throws Exception {
        OutputStream out = getContentResolver().openOutputStream(uri);
        out.write(value.getBytes("UTF-8"));
        out.close();
    }

    private String readString(Uri uri) throws Exception {
        InputStream in = getContentResolver().openInputStream(uri);
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        byte[] buffer = new byte[8192];
        int read;
        while (in != null && (read = in.read(buffer)) != -1) out.write(buffer, 0, read);
        if (in != null) in.close();
        return out.toString("UTF-8");
    }

    private String displayName(Uri uri) {
        try (android.database.Cursor cursor = getContentResolver().query(uri, null, null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                int index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                if (index >= 0) return cursor.getString(index);
            }
        } catch (Exception ignored) {}
        return "attachment-" + System.currentTimeMillis();
    }

    private ScrollView scroll() {
        ScrollView scroll = new ScrollView(this);
        content.addView(scroll, new LinearLayout.LayoutParams(-1, -1));
        return scroll;
    }

    private LinearLayout page(ScrollView scroll) {
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setPadding(dp(18), dp(16), dp(18), dp(30));
        scroll.addView(page);
        return page;
    }

    private LinearLayout row() {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        return row;
    }

    private TextView title(String value) {
        TextView tv = text(value, 22, true);
        tv.setPadding(0, dp(6), 0, dp(14));
        return tv;
    }

    private TextView sectionTitle(String value) {
        TextView tv = text(value, 15, true);
        tv.setPadding(0, dp(18), 0, dp(8));
        return tv;
    }

    private TextView text(String value, int sp, boolean bold) {
        TextView tv = new TextView(this);
        tv.setText(value);
        tv.setTextSize(sp);
        tv.setTextColor(ink());
        tv.setTypeface(Typeface.DEFAULT, bold ? Typeface.BOLD : Typeface.NORMAL);
        tv.setLineSpacing(2, 1);
        return tv;
    }

    private TextView empty(String value) {
        TextView tv = text(value, 14, false);
        tv.setPadding(dp(12), dp(12), dp(12), dp(12));
        tv.setBackground(rounded(cardColor(), dp(12), divider(), 1));
        return tv;
    }

    private LinearLayout cardBase() {
        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setPadding(dp(16), dp(14), dp(16), dp(14));
        card.setBackground(rounded(cardColor(), dp(18), divider(), 1));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
        lp.setMargins(0, 0, 0, dp(10));
        card.setLayoutParams(lp);
        return card;
    }

    private View card(String value, View.OnClickListener listener) {
        LinearLayout card = cardBase();
        card.addView(text(value, 15, true));
        card.setOnClickListener(listener);
        return card;
    }

    private Button action(String value, View.OnClickListener listener) {
        Button b = button(value, listener);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, dp(64), 1);
        lp.setMargins(0, 0, dp(8), dp(8));
        b.setLayoutParams(lp);
        return b;
    }

    private Button button(String value) {
        return button(value, null);
    }

    private Button button(String value, View.OnClickListener listener) {
        Button b = new Button(this);
        b.setText(value);
        b.setAllCaps(false);
        b.setTextColor(Color.WHITE);
        b.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        b.setBackground(rounded(accent(), dp(18), Color.TRANSPARENT, 0));
        if (listener != null) b.setOnClickListener(listener);
        return b;
    }

    private void addInput(LinearLayout page, String tag, String label, String value) {
        addInputField(page, tag, label, value);
    }

    private void addTwoInputs(LinearLayout page, String tag1, String label1, String value1, String tag2, String label2, String value2) {
        LinearLayout row = row();
        row.setGravity(Gravity.TOP);
        LinearLayout first = fieldColumn();
        LinearLayout second = fieldColumn();
        addInputField(first, tag1, label1, value1);
        addInputField(second, tag2, label2, value2);
        LinearLayout.LayoutParams left = new LinearLayout.LayoutParams(0, -2, 1);
        left.setMargins(0, 0, dp(6), 0);
        LinearLayout.LayoutParams right = new LinearLayout.LayoutParams(0, -2, 1);
        right.setMargins(dp(6), 0, 0, 0);
        row.addView(first, left);
        row.addView(second, right);
        page.addView(row);
    }

    private LinearLayout fieldColumn() {
        LinearLayout column = new LinearLayout(this);
        column.setOrientation(LinearLayout.VERTICAL);
        return column;
    }

    private void addInputField(LinearLayout page, String tag, String label, String value) {
        TextView l = text(label, 12, true);
        l.setPadding(0, dp(8), 0, dp(3));
        page.addView(l);
        EditText input = new EditText(this);
        input.setTag(tag);
        input.setText(value == null ? "" : value);
        input.setSingleLine(true);
        input.setTextColor(ink());
        input.setHintTextColor(muted());
        input.setBackground(rounded(inputBg(), dp(14), divider(), 1));
        input.setPadding(dp(10), 0, dp(10), 0);
        page.addView(input, new LinearLayout.LayoutParams(-1, dp(46)));
    }

    private void addMulti(LinearLayout page, String tag, String label, String value) {
        TextView l = text(label, 12, true);
        l.setPadding(0, dp(8), 0, dp(3));
        page.addView(l);
        EditText input = new EditText(this);
        input.setTag(tag);
        input.setText(value == null ? "" : value);
        input.setMinLines(3);
        input.setGravity(Gravity.TOP);
        input.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE);
        input.setTextColor(ink());
        input.setBackground(rounded(inputBg(), dp(14), divider(), 1));
        input.setPadding(dp(10), dp(8), dp(10), dp(8));
        page.addView(input, new LinearLayout.LayoutParams(-1, dp(104)));
    }

    private void addSpinner(LinearLayout page, String label, int selected, String[] items, IntCallback callback) {
        TextView l = text(label, 12, true);
        l.setPadding(0, dp(8), 0, dp(3));
        page.addView(l);
        Spinner spinner = new Spinner(this);
        ArrayAdapter<String> adapter = new ArrayAdapter<>(this, android.R.layout.simple_spinner_dropdown_item, items);
        spinner.setAdapter(adapter);
        spinner.setSelection(Math.max(0, selected));
        spinner.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            boolean first = true;
            @Override public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                if (first) {
                    first = false;
                    return;
                }
                callback.call(position);
            }
            @Override public void onNothingSelected(AdapterView<?> parent) {}
        });
        page.addView(spinner, new LinearLayout.LayoutParams(-1, dp(48)));
    }

    private interface IntCallback { void call(int value); }

    private int dp(int value) {
        return (int) (value * getResources().getDisplayMetrics().density + 0.5f);
    }
    private int statusBarInset() {
        int id = getResources().getIdentifier("status_bar_height", "dimen", "android");
        return id > 0 ? getResources().getDimensionPixelSize(id) : 0;
    }
    private int navigationBarInset() {
        int id = getResources().getIdentifier("navigation_bar_height", "dimen", "android");
        return id > 0 ? getResources().getDimensionPixelSize(id) : 0;
    }

    private int bg() { return darkMode ? Color.rgb(21, 25, 29) : Color.rgb(244, 246, 244); }
    private int panel() { return darkMode ? Color.rgb(34, 39, 44) : Color.rgb(251, 250, 247); }
    private int cardColor() { return darkMode ? Color.rgb(39, 45, 51) : Color.WHITE; }
    private int inputBg() { return darkMode ? Color.rgb(48, 56, 64) : Color.rgb(233, 238, 234); }
    private int ink() { return darkMode ? Color.rgb(232, 236, 233) : Color.rgb(30, 42, 50); }
    private int muted() { return darkMode ? Color.rgb(184, 194, 188) : Color.rgb(104, 115, 125); }
    private int divider() { return darkMode ? Color.rgb(61, 70, 78) : Color.rgb(220, 226, 222); }
    private int transparentPanel() { return darkMode ? Color.rgb(48, 56, 64) : Color.rgb(233, 238, 234); }
    private int accent() { return darkMode ? Color.rgb(141, 163, 153) : Color.rgb(47, 58, 54); }

    private GradientDrawable rounded(int fill, int radius, int strokeColor, int strokeWidth) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(fill);
        drawable.setCornerRadius(radius);
        if (strokeWidth > 0) drawable.setStroke(dp(strokeWidth), strokeColor);
        return drawable;
    }

    private void toast(String s) { Toast.makeText(this, s, Toast.LENGTH_SHORT).show(); }

    private void confirm(String message, Runnable onYes) {
        new AlertDialog.Builder(this)
            .setMessage(message)
            .setPositiveButton(t("delete"), (d, w) -> onYes.run())
            .setNegativeButton(t("cancel"), null)
            .show();
    }

    private String t(String key) { return Texts.t(key, store.language); }
    private String date(long millis) { return new SimpleDateFormat("yyyy-MM-dd", Locale.US).format(new Date(millis)); }
    private long parseDate(String value) {
        try { return new SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(value).getTime(); }
        catch (Exception e) { return System.currentTimeMillis(); }
    }
    private String money(double value) { return NumberFormat.getCurrencyInstance(Locale.JAPAN).format(value); }
    private String trim(double value) { return Math.abs(value - Math.round(value)) < 0.0001 ? String.valueOf((long) value) : String.valueOf(value); }
    private double parseDouble(String value) { return parseDouble(value, 0); }
    private double parseDouble(String value, double fallback) {
        try { return Double.parseDouble(value.replace(",", "").trim()); }
        catch (Exception e) { return fallback; }
    }
    private String safe(String s) { return s == null ? "" : s; }
    private String first(Map<String, List<String>> values, String key, String fallback) {
        List<String> list = values.get(key);
        return list == null || list.isEmpty() ? fallback : list.get(0);
    }
    private String get(List<String> list, int i) { return list == null || i >= list.size() ? "" : list.get(i); }
    private String fileBase(BusinessDocument d) {
        String base = (d.number.isEmpty() ? d.type.title(store.language) : d.number + "-" + d.type.title(store.language));
        return base.replaceAll("[^A-Za-z0-9._-]+", "-");
    }

    public static class PreviewCanvas extends View {
        static final float PAGE_ASPECT = 842f / 595f;
        BusinessDocument document;
        AppLanguage language = AppLanguage.JAPANESE;
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final ScaleGestureDetector scaleGestureDetector;
        private HorizontalScrollView horizontalScrollView;
        private ScrollView scrollView;
        private int basePageWidth;
        private float zoom = 1f;
        private final int pagePadding;

        public PreviewCanvas(Context context) {
            super(context);
            pagePadding = (int) (18 * context.getResources().getDisplayMetrics().density + 0.5f);
            scaleGestureDetector = new ScaleGestureDetector(context, new ScaleGestureDetector.SimpleOnScaleGestureListener() {
                @Override public boolean onScale(ScaleGestureDetector detector) {
                    adjustZoom(detector.getScaleFactor());
                    return true;
                }
            });
            setLayerType(View.LAYER_TYPE_SOFTWARE, null);
        }

        void configure(int fitPageWidth, HorizontalScrollView horizontal, ScrollView vertical) {
            horizontalScrollView = horizontal;
            scrollView = vertical;
            basePageWidth = Math.max(240, fitPageWidth);
            fitWidth();
        }

        void fitWidth() {
            zoom = 1f;
            applySize();
        }

        void adjustZoom(float factor) {
            zoom = Math.max(0.72f, Math.min(2.4f, zoom * factor));
            applySize();
        }

        private void applySize() {
            if (basePageWidth <= 0) return;
            int pageWidth = Math.max(1, Math.round(basePageWidth * zoom));
            int pageHeight = Math.round(pageWidth * PAGE_ASPECT);
            ViewGroup.LayoutParams params = getLayoutParams();
            if (params == null) params = new FrameLayout.LayoutParams(pageWidth + pagePadding * 2, pageHeight + pagePadding * 2);
            params.width = pageWidth + pagePadding * 2;
            params.height = pageHeight + pagePadding * 2;
            setLayoutParams(params);
            invalidate();
        }

        @Override public boolean onTouchEvent(MotionEvent event) {
            if (event.getPointerCount() > 1 && scrollView != null) scrollView.requestDisallowInterceptTouchEvent(true);
            boolean handled = scaleGestureDetector.onTouchEvent(event);
            if (event.getActionMasked() == MotionEvent.ACTION_UP || event.getActionMasked() == MotionEvent.ACTION_CANCEL) {
                if (scrollView != null) scrollView.requestDisallowInterceptTouchEvent(false);
            }
            return handled || super.onTouchEvent(event);
        }

        @Override protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);
            int pageWidth = Math.max(1, getWidth() - pagePadding * 2);
            int pageHeight = Math.max(1, getHeight() - pagePadding * 2);
            float left = pagePadding;
            float top = pagePadding;
            RectF shadow = new RectF(left, top, left + pageWidth, top + pageHeight);
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(Color.argb(55, 0, 0, 0));
            paint.setShadowLayer(12, 0, 5, Color.argb(80, 0, 0, 0));
            canvas.drawRoundRect(shadow, 8, 8, paint);
            paint.clearShadowLayer();
            paint.setColor(Color.WHITE);
            canvas.drawRect(shadow, paint);
            if (document != null) {
                canvas.save();
                canvas.translate(left, top);
                canvas.clipRect(0, 0, pageWidth, pageHeight);
                PdfRenderer.draw(canvas, document, language, pageWidth, pageHeight, pageWidth / 595f);
                canvas.restore();
            }
        }
    }

    enum AppLanguage {
        JAPANESE, SIMPLIFIED_CHINESE, TRADITIONAL_CHINESE, ENGLISH, KOREAN, NEPALI, FRENCH, VIETNAMESE;
        static String[] names() { return new String[]{"日本語", "简体中文", "繁體中文", "English", "한국어", "नेपाली", "Français", "Tiếng Việt"}; }
        static AppLanguage fromStorage(String raw) {
            if ("CHINESE".equals(raw)) return SIMPLIFIED_CHINESE;
            try { return AppLanguage.valueOf(raw); } catch (Exception ignored) { return systemDefault(); }
        }
        static AppLanguage systemDefault() {
            String language = Locale.getDefault().getLanguage();
            String country = Locale.getDefault().getCountry();
            if ("ko".equals(language)) return KOREAN;
            if ("zh".equals(language) && ("TW".equals(country) || "HK".equals(country) || "MO".equals(country))) return TRADITIONAL_CHINESE;
            if ("zh".equals(language)) return SIMPLIFIED_CHINESE;
            if ("ja".equals(language)) return JAPANESE;
            if ("ne".equals(language)) return NEPALI;
            if ("fr".equals(language)) return FRENCH;
            if ("vi".equals(language)) return VIETNAMESE;
            if ("en".equals(language)) return ENGLISH;
            return JAPANESE;
        }
    }

    enum ProjectDirection {
        CUSTOMER, VENDOR;
        String title(AppLanguage l) {
            if (this == CUSTOMER) return isChinese(l) ? "给客户" : l == AppLanguage.ENGLISH ? "Customer" : "顧客向け";
            return isChinese(l) ? "给供应商" : l == AppLanguage.ENGLISH ? "Vendor" : "仕入先向け";
        }
        DocumentType[] requiredTypes() {
            return this == CUSTOMER
                ? new DocumentType[]{DocumentType.ESTIMATE, DocumentType.CUSTOMER_ORDER, DocumentType.DELIVERY, DocumentType.INVOICE, DocumentType.RECEIPT}
                : new DocumentType[]{DocumentType.VENDOR_ESTIMATE, DocumentType.PURCHASE_ORDER, DocumentType.ACCEPTANCE, DocumentType.VENDOR_INVOICE, DocumentType.VENDOR_RECEIPT};
        }
        DocumentType firstType() { return requiredTypes()[0]; }
    }

    enum DocumentType {
        ESTIMATE("EST"), CUSTOMER_ORDER("ORD"), PURCHASE_ORDER("PO"), DELIVERY("DLV"), INVOICE("INV"), RECEIPT("RCT"),
        ACCEPTANCE("ACP"), CUSTOMER_FILES("CF"), VENDOR_ESTIMATE("VEST"), VENDOR_INVOICE("VINV"), VENDOR_RECEIPT("VRCT"), PAYMENT_NOTICE("PAY");
        final String prefix;
        DocumentType(String prefix) { this.prefix = prefix; }
        static String[] titles(AppLanguage l) {
            DocumentType[] values = visibleValues();
            String[] titles = new String[values.length];
            for (int i = 0; i < values.length; i++) titles[i] = values[i].title(l);
            return titles;
        }
        static DocumentType[] visibleValues() {
            ArrayList<DocumentType> types = new ArrayList<>();
            for (DocumentType type : values()) if (!type.isHidden()) types.add(type);
            return types.toArray(new DocumentType[0]);
        }
        String title(AppLanguage l) {
            switch (this) {
                case ESTIMATE: return local(l, "見積書", "报价单", "Quote");
                case CUSTOMER_ORDER: return local(l, "受注", "受注", "Order Received");
                case PURCHASE_ORDER: return local(l, "発注書", "采购订单", "Purchase Order");
                case DELIVERY: return local(l, "納品書", "送货单", "Delivery Note");
                case INVOICE: return local(l, "請求書", "发票", "Invoice");
                case RECEIPT: return local(l, "領収書", "收据", "Receipt");
                case ACCEPTANCE: return local(l, "受領書", "收货确认单", "Acceptance Receipt");
                case CUSTOMER_FILES: return local(l, "プロジェクト管理", "项目管理", "Project Documents");
                case VENDOR_ESTIMATE: return local(l, "仕入先見積記録", "厂商报价单记录", "Vendor Quote Record");
                case VENDOR_INVOICE: return local(l, "仕入先請求書記録", "厂商请款书记录", "Vendor Invoice Record");
                case VENDOR_RECEIPT: return local(l, "仕入先領収書記録", "厂商收据记录", "Vendor Receipt Record");
                default: return local(l, "支払通知書", "支付告知通知书", "Payment Notice");
            }
        }
        String subtitle(AppLanguage l) { return name().replace('_', ' '); }
        boolean isAttachmentRecord() { return this == CUSTOMER_ORDER || this == VENDOR_ESTIMATE || this == VENDOR_INVOICE || this == VENDOR_RECEIPT || this == PAYMENT_NOTICE; }
        boolean isHidden() { return this == PAYMENT_NOTICE; }
        boolean isVendorForm() { return this == VENDOR_ESTIMATE || this == VENDOR_INVOICE || this == PURCHASE_ORDER || this == ACCEPTANCE || this == VENDOR_RECEIPT || this == PAYMENT_NOTICE; }
        boolean showsDueDate() { return this == INVOICE || this == PAYMENT_NOTICE; }
        boolean showsLinePrices() { return this == ESTIMATE || this == INVOICE || this == RECEIPT || this == PURCHASE_ORDER || this == PAYMENT_NOTICE; }
        boolean showsTax() { return showsLinePrices(); }
        boolean showsPaymentDetails() { return this == INVOICE; }
        boolean showsIssuerRegistration() { return this == INVOICE || this == RECEIPT; }
        String totalLabel(AppLanguage l) {
            switch (this) {
                case ESTIMATE: return local(l, "御見積金額", "报价金额", "Quote Total");
                case PURCHASE_ORDER: return local(l, "発注金額", "采购金额", "Purchase Total");
                case INVOICE: return local(l, "ご請求金額", "应付金额", "Amount Due");
                case RECEIPT: return local(l, "領収金額", "收款金额", "Amount Received");
                default: return local(l, "記録金額", "记录金额", "Recorded Amount");
            }
        }
    }

    enum ColorTemplate {
        MONOCHROME(Color.rgb(46, 48, 49)), OCEAN(Color.rgb(37, 99, 235)), MINT(Color.rgb(15, 118, 110)),
        ROSE(Color.rgb(190, 18, 60)), AMBER(Color.rgb(180, 83, 9)), GRAPHITE(Color.rgb(71, 85, 105));
        final int accent;
        ColorTemplate(int accent) { this.accent = accent; }
        static String[] names() { return new String[]{"日本帳票", "海藍表格", "薄荷表格", "玫瑰表格", "琥珀表格", "石墨表格"}; }
    }

    static String local(AppLanguage l, String ja, String zh, String en) {
        if (isChinese(l)) return zh;
        if (l == AppLanguage.ENGLISH || l == AppLanguage.KOREAN || l == AppLanguage.NEPALI || l == AppLanguage.FRENCH || l == AppLanguage.VIETNAMESE) return en;
        return ja;
    }

    static boolean isChinese(AppLanguage l) {
        return l == AppLanguage.SIMPLIFIED_CHINESE || l == AppLanguage.TRADITIONAL_CHINESE;
    }

    class BillingManager implements PurchasesUpdatedListener {
        static final String MONTHLY_PRODUCT_ID = "monthly";
        static final String YEARLY_PRODUCT_ID = "yearly";
        static final String YEARLY_ALIAS_PRODUCT_ID = "annual";

        private final Activity activity;
        private final BillingClient billingClient;
        private final Map<String, ProductDetails> productDetails = new HashMap<>();
        private boolean isReady = false;

        BillingManager(Activity activity) {
            this.activity = activity;
            billingClient = BillingClient.newBuilder(activity)
                .setListener(this)
                .enablePendingPurchases(
                    PendingPurchasesParams.newBuilder()
                        .enableOneTimeProducts()
                        .build()
                )
                .build();
        }

        void start() {
            billingClient.startConnection(new BillingClientStateListener() {
                @Override
                public void onBillingSetupFinished(BillingResult billingResult) {
                    if (billingResult.getResponseCode() != BillingClient.BillingResponseCode.OK) {
                        isReady = false;
                        return;
                    }
                    isReady = true;
                    queryProducts();
                    syncPurchases(false);
                }

                @Override
                public void onBillingServiceDisconnected() {
                    isReady = false;
                }
            });
        }

        void destroy() {
            if (billingClient.isReady()) billingClient.endConnection();
        }

        String priceFor(String productId) {
            ProductDetails details = productDetails.get(productId);
            if (details == null && YEARLY_PRODUCT_ID.equals(productId)) details = productDetails.get(YEARLY_ALIAS_PRODUCT_ID);
            if (details == null || details.getSubscriptionOfferDetails() == null || details.getSubscriptionOfferDetails().isEmpty()) return "";
            List<ProductDetails.PricingPhase> phases = details.getSubscriptionOfferDetails().get(0).getPricingPhases().getPricingPhaseList();
            if (phases == null || phases.isEmpty()) return "";
            return phases.get(0).getFormattedPrice();
        }

        void purchase(String productId) {
            if (!isReady) {
                toast(t("billingNotReady"));
                start();
                return;
            }
            ProductDetails details = productDetails.get(productId);
            if (details == null && YEARLY_PRODUCT_ID.equals(productId)) details = productDetails.get(YEARLY_ALIAS_PRODUCT_ID);
            if (details == null) {
                toast(t("productUnavailable"));
                queryProducts();
                return;
            }
            List<ProductDetails.SubscriptionOfferDetails> offers = details.getSubscriptionOfferDetails();
            if (offers == null || offers.isEmpty()) {
                toast(t("productUnavailable"));
                return;
            }
            BillingFlowParams.ProductDetailsParams productParams = BillingFlowParams.ProductDetailsParams.newBuilder()
                .setProductDetails(details)
                .setOfferToken(offers.get(0).getOfferToken())
                .build();
            ArrayList<BillingFlowParams.ProductDetailsParams> params = new ArrayList<>();
            params.add(productParams);
            BillingFlowParams flowParams = BillingFlowParams.newBuilder()
                .setProductDetailsParamsList(params)
                .build();
            billingClient.launchBillingFlow(activity, flowParams);
        }

        void restorePurchases() {
            syncPurchases(true);
        }

        private void syncPurchases(boolean showStatus) {
            if (!isReady) {
                if (showStatus) toast(t("billingNotReady"));
                start();
                return;
            }
            billingClient.queryPurchasesAsync(
                QueryPurchasesParams.newBuilder()
                    .setProductType(BillingClient.ProductType.SUBS)
                    .build(),
                (billingResult, purchases) -> {
                    if (billingResult.getResponseCode() != BillingClient.BillingResponseCode.OK) {
                        if (showStatus) runOnUiThread(() -> toast(t("restoreFailed")));
                        return;
                    }
                    boolean hasPro = false;
                    for (Purchase purchase : purchases) {
                        if (isProPurchase(purchase)) {
                            hasPro = true;
                            acknowledgeIfNeeded(purchase);
                        }
                    }
                    boolean finalHasPro = hasPro;
                    runOnUiThread(() -> setProUnlocked(finalHasPro, showStatus ? (finalHasPro ? "restoreComplete" : "restoreEmpty") : null));
                }
            );
        }

        private void queryProducts() {
            ArrayList<QueryProductDetailsParams.Product> products = new ArrayList<>();
            for (String id : new String[]{MONTHLY_PRODUCT_ID, YEARLY_PRODUCT_ID, YEARLY_ALIAS_PRODUCT_ID}) {
                products.add(QueryProductDetailsParams.Product.newBuilder()
                    .setProductId(id)
                    .setProductType(BillingClient.ProductType.SUBS)
                    .build());
            }
            QueryProductDetailsParams params = QueryProductDetailsParams.newBuilder()
                .setProductList(products)
                .build();
            billingClient.queryProductDetailsAsync(params, (billingResult, result) -> {
                if (billingResult.getResponseCode() != BillingClient.BillingResponseCode.OK) return;
                productDetails.clear();
                for (ProductDetails details : result.getProductDetailsList()) {
                    productDetails.put(details.getProductId(), details);
                }
                if ("settings".equals(section)) runOnUiThread(() -> showSettings());
            });
        }

        @Override
        public void onPurchasesUpdated(BillingResult billingResult, List<Purchase> purchases) {
            if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.USER_CANCELED) {
                toast(t("purchaseCancelled"));
                return;
            }
            if (billingResult.getResponseCode() != BillingClient.BillingResponseCode.OK || purchases == null) {
                toast(t("purchaseFailed"));
                return;
            }
            boolean hasPro = false;
            for (Purchase purchase : purchases) {
                if (isProPurchase(purchase)) {
                    hasPro = true;
                    acknowledgeIfNeeded(purchase);
                }
            }
            if (hasPro) setProUnlocked(true, "purchaseComplete");
        }

        private boolean isProPurchase(Purchase purchase) {
            if (purchase.getPurchaseState() != Purchase.PurchaseState.PURCHASED) return false;
            for (String productId : purchase.getProducts()) {
                if (MONTHLY_PRODUCT_ID.equals(productId) || YEARLY_PRODUCT_ID.equals(productId) || YEARLY_ALIAS_PRODUCT_ID.equals(productId)) return true;
            }
            return false;
        }

        private void acknowledgeIfNeeded(Purchase purchase) {
            if (purchase.isAcknowledged()) return;
            AcknowledgePurchaseParams params = AcknowledgePurchaseParams.newBuilder()
                .setPurchaseToken(purchase.getPurchaseToken())
                .build();
            billingClient.acknowledgePurchase(params, billingResult -> {});
        }
    }

    static class LineItem {
        String id = UUID.randomUUID().toString();
        String name = "";
        String model = "";
        String specification = "";
        double quantity = 1;
        double unitPrice = 0;
        double amount() { return quantity * unitPrice; }
        JSONObject toJson() throws JSONException {
            JSONObject o = new JSONObject();
            o.put("id", id); o.put("name", name); o.put("model", model); o.put("specification", specification); o.put("quantity", quantity); o.put("unitPrice", unitPrice);
            return o;
        }
        static LineItem fromJson(JSONObject o) {
            LineItem l = new LineItem();
            l.id = o.optString("id", l.id); l.name = o.optString("name"); l.model = o.optString("model"); l.specification = o.optString("specification");
            l.quantity = o.optDouble("quantity", 1); l.unitPrice = o.optDouble("unitPrice", 0);
            return l;
        }
    }

    static class OrderAttachment {
        String id = UUID.randomUUID().toString();
        String filename = "";
        String contentType = "";
        byte[] bytes = new byte[0];
        JSONObject toJson() throws JSONException {
            JSONObject o = new JSONObject();
            o.put("id", id); o.put("filename", filename); o.put("contentType", contentType); o.put("data", android.util.Base64.encodeToString(bytes, android.util.Base64.NO_WRAP));
            return o;
        }
        static OrderAttachment fromJson(JSONObject o) {
            OrderAttachment a = new OrderAttachment();
            a.id = o.optString("id", a.id); a.filename = o.optString("filename"); a.contentType = o.optString("contentType");
            a.bytes = android.util.Base64.decode(o.optString("data", ""), android.util.Base64.DEFAULT);
            return a;
        }
    }

    static class BusinessDocument {
        String id = UUID.randomUUID().toString();
        String projectId, projectName, projectDirection;
        DocumentType type = DocumentType.INVOICE;
        String number = "";
        long issueDate = System.currentTimeMillis();
        long transactionDate = System.currentTimeMillis();
        long dueDate = System.currentTimeMillis() + 30L * 86400000L;
        String relatedNumber = "", honorific = "御中";
        double taxRate = 10;
        ColorTemplate colorTemplate = ColorTemplate.MONOCHROME;
        String customerName = "", customerAddress = "", customerContact = "", customerPhone = "", customerEmail = "";
        String issuerName = "NIIX株式会社", issuerRegistration = "", issuerAddress = "東京都", issuerContact = "", issuerPhone = "", issuerEmail = "";
        String notes = "", paymentDetails = "", documentMemo = "";
        ArrayList<LineItem> lines = new ArrayList<>();
        ArrayList<OrderAttachment> orderAttachments = new ArrayList<>();
        long paymentProofDate = System.currentTimeMillis();
        double paymentProofAmount = 0;
        ArrayList<OrderAttachment> paymentProofAttachments = new ArrayList<>();
        String googleDrivePDFFileID, googleDriveJSONFileID;
        long updatedAt = System.currentTimeMillis();
        BusinessDocument() { lines.add(defaultLine()); }
        static LineItem defaultLine() { LineItem l = new LineItem(); l.name = "商品・サービス"; return l; }
        static BusinessDocument blank(DocumentType type, String number) {
            BusinessDocument d = new BusinessDocument();
            d.type = type; d.number = number; d.notes = defaultNotes(type); d.documentMemo = defaultMemo(type);
            if (type.isVendorForm()) d.paymentProofAmount = d.total();
            if (type.isAttachmentRecord()) d.orderAttachments = new ArrayList<>();
            return d;
        }
        double subtotal() { double s = 0; for (LineItem l : lines) s += l.amount(); return s; }
        double tax() { return subtotal() * taxRate / 100; }
        double total() { return subtotal() + tax(); }
        double displayTotal() { return type.showsTax() ? total() : subtotal(); }
        BusinessDocument copy() {
            try { return fromJson(toJson()); } catch (Exception e) { return this; }
        }
        JSONObject toJson() throws JSONException {
            JSONObject o = new JSONObject();
            o.put("id", id); o.put("projectId", projectId); o.put("projectName", projectName); o.put("projectDirection", projectDirection);
            o.put("type", type.name()); o.put("number", number); o.put("issueDate", issueDate); o.put("transactionDate", transactionDate); o.put("dueDate", dueDate);
            o.put("relatedNumber", relatedNumber); o.put("honorific", honorific); o.put("taxRate", taxRate); o.put("colorTemplate", colorTemplate.name());
            o.put("customerName", customerName); o.put("customerAddress", customerAddress); o.put("customerContact", customerContact); o.put("customerPhone", customerPhone); o.put("customerEmail", customerEmail);
            o.put("issuerName", issuerName); o.put("issuerRegistration", issuerRegistration); o.put("issuerAddress", issuerAddress); o.put("issuerContact", issuerContact); o.put("issuerPhone", issuerPhone); o.put("issuerEmail", issuerEmail);
            o.put("notes", notes); o.put("paymentDetails", paymentDetails); o.put("documentMemo", documentMemo); o.put("paymentProofDate", paymentProofDate); o.put("paymentProofAmount", paymentProofAmount);
            o.put("googleDrivePDFFileID", googleDrivePDFFileID); o.put("googleDriveJSONFileID", googleDriveJSONFileID); o.put("updatedAt", updatedAt);
            JSONArray lineArray = new JSONArray(); for (LineItem l : lines) lineArray.put(l.toJson()); o.put("lines", lineArray);
            JSONArray attachArray = new JSONArray(); for (OrderAttachment a : orderAttachments) attachArray.put(a.toJson()); o.put("orderAttachments", attachArray);
            JSONArray proofArray = new JSONArray(); for (OrderAttachment a : paymentProofAttachments) proofArray.put(a.toJson()); o.put("paymentProofAttachments", proofArray);
            return o;
        }
        static BusinessDocument fromJson(JSONObject o) {
            BusinessDocument d = new BusinessDocument();
            d.id = o.optString("id", d.id); d.projectId = optNull(o, "projectId"); d.projectName = optNull(o, "projectName"); d.projectDirection = optNull(o, "projectDirection");
            d.type = DocumentType.valueOf(o.optString("type", DocumentType.INVOICE.name())); d.number = o.optString("number");
            d.issueDate = o.optLong("issueDate", d.issueDate); d.transactionDate = o.optLong("transactionDate", d.transactionDate); d.dueDate = o.optLong("dueDate", d.dueDate);
            d.relatedNumber = o.optString("relatedNumber"); d.honorific = o.optString("honorific", "御中"); d.taxRate = o.optDouble("taxRate", 10);
            d.colorTemplate = ColorTemplate.valueOf(o.optString("colorTemplate", ColorTemplate.MONOCHROME.name()));
            d.customerName = o.optString("customerName"); d.customerAddress = o.optString("customerAddress"); d.customerContact = o.optString("customerContact"); d.customerPhone = o.optString("customerPhone"); d.customerEmail = o.optString("customerEmail");
            d.issuerName = o.optString("issuerName", "NIIX株式会社"); d.issuerRegistration = o.optString("issuerRegistration"); d.issuerAddress = o.optString("issuerAddress", "東京都"); d.issuerContact = o.optString("issuerContact"); d.issuerPhone = o.optString("issuerPhone"); d.issuerEmail = o.optString("issuerEmail");
            d.notes = o.optString("notes"); d.paymentDetails = o.optString("paymentDetails"); d.documentMemo = o.optString("documentMemo");
            d.paymentProofDate = o.optLong("paymentProofDate", d.paymentProofDate); d.paymentProofAmount = o.optDouble("paymentProofAmount", d.paymentProofAmount);
            d.googleDrivePDFFileID = optNull(o, "googleDrivePDFFileID"); d.googleDriveJSONFileID = optNull(o, "googleDriveJSONFileID"); d.updatedAt = o.optLong("updatedAt", d.updatedAt);
            d.lines.clear(); JSONArray lines = o.optJSONArray("lines"); if (lines != null) for (int i = 0; i < lines.length(); i++) d.lines.add(LineItem.fromJson(lines.optJSONObject(i)));
            if (d.lines.isEmpty()) d.lines.add(defaultLine());
            d.orderAttachments.clear(); JSONArray attachments = o.optJSONArray("orderAttachments"); if (attachments != null) for (int i = 0; i < attachments.length(); i++) d.orderAttachments.add(OrderAttachment.fromJson(attachments.optJSONObject(i)));
            d.paymentProofAttachments.clear(); JSONArray proof = o.optJSONArray("paymentProofAttachments"); if (proof != null) for (int i = 0; i < proof.length(); i++) d.paymentProofAttachments.add(OrderAttachment.fromJson(proof.optJSONObject(i)));
            return d;
        }
        static String defaultNotes(DocumentType type) {
            switch (type) {
                case ESTIMATE: return "見積条件、納入予定、税率・合計金額を確認してください。";
                case PURCHASE_ORDER: return "注文内容をご確認の上、手配をお願いいたします。";
                case DELIVERY: return "上記の通り納品いたします。";
                case INVOICE: return "振込手数料は貴社にてご負担ください。";
                case RECEIPT: return "上記の金額を領収いたしました。";
                case ACCEPTANCE: return "上記の通り、受領いたしました。";
                default: return "関連ファイルを添付し、取引内容を確認してください。";
            }
        }
        static String defaultMemo(DocumentType type) {
            return type.isAttachmentRecord() ? "関連資料をまとめて保存します。" : "";
        }
    }

    static class DeletedDocumentRecord {
        static final long RETENTION_MS = 30L * 86400000L;
        String id = UUID.randomUUID().toString();
        BusinessDocument document = BusinessDocument.blank(DocumentType.INVOICE, "");
        long deletedAt = System.currentTimeMillis();
        long expiresAt() { return deletedAt + RETENTION_MS; }
        JSONObject toJson() throws JSONException {
            JSONObject o = new JSONObject();
            o.put("id", id);
            o.put("deletedAt", deletedAt);
            o.put("document", document.toJson());
            return o;
        }
        static DeletedDocumentRecord fromJson(JSONObject o) {
            DeletedDocumentRecord r = new DeletedDocumentRecord();
            r.id = o.optString("id", r.id);
            r.deletedAt = o.optLong("deletedAt", r.deletedAt);
            JSONObject doc = o.optJSONObject("document");
            if (doc != null) r.document = BusinessDocument.fromJson(doc);
            return r;
        }
        boolean expired() { return System.currentTimeMillis() > expiresAt(); }
    }

    static String optNull(JSONObject o, String key) { return o.isNull(key) ? null : o.optString(key, null); }

    static class CustomerProfile {
        String id = UUID.randomUUID().toString(), name = "", contact = "", phone = "", email = "", address = "";
        long updatedAt = System.currentTimeMillis();
    }
    static class IssuerProfile {
        String id = UUID.randomUUID().toString(), name = "", registration = "", contact = "", phone = "", email = "", address = "";
        long updatedAt = System.currentTimeMillis();
    }
    static class ProductProfile {
        String id = UUID.randomUUID().toString(), name = "", model = "", specification = "";
        double unitPrice = 0;
        long updatedAt = System.currentTimeMillis();
    }
    static class TextTemplate {
        String id = UUID.randomUUID().toString(), kind = "note", title = "", content = "";
        long updatedAt = System.currentTimeMillis();
    }

    static class ProjectArchive {
        String id, name, customerName;
        ProjectDirection direction;
        ArrayList<BusinessDocument> documents = new ArrayList<>();
        int completedCount() {
            int count = 0;
            for (DocumentType type : direction.requiredTypes()) if (document(type) != null) count++;
            return count;
        }
        BusinessDocument document(DocumentType type) {
            for (BusinessDocument d : documents) if (d.type == type) return d;
            return null;
        }
    }

    class Store {
        ArrayList<BusinessDocument> documents = new ArrayList<>();
        ArrayList<DeletedDocumentRecord> deletedDocuments = new ArrayList<>();
        ArrayList<CustomerProfile> customers = new ArrayList<>();
        ArrayList<IssuerProfile> issuers = new ArrayList<>();
        ArrayList<ProductProfile> products = new ArrayList<>();
        ArrayList<TextTemplate> templates = new ArrayList<>();
        BusinessDocument current = BusinessDocument.blank(DocumentType.INVOICE, "INV-" + new SimpleDateFormat("yyyyMMdd-HHmm", Locale.US).format(new Date()));
        boolean hasActiveDocument;
        AppLanguage language = AppLanguage.systemDefault();
        AppLanguage pdfLanguage = AppLanguage.systemDefault();
        ColorTemplate defaultColor = ColorTemplate.MONOCHROME;

        void load(Context c) {
            try {
                String raw = c.getSharedPreferences("shoko.android.store", MODE_PRIVATE).getString("json", null);
                if (raw != null) fromJson(new JSONObject(raw));
            } catch (Exception ignored) {}
            if (issuers.isEmpty()) {
                IssuerProfile issuer = new IssuerProfile();
                issuer.name = "NIIX株式会社";
                issuer.address = "東京都";
                issuers.add(issuer);
            }
        }
        void save(Context c) {
            try {
                c.getSharedPreferences("shoko.android.store", MODE_PRIVATE).edit().putString("json", toJson().toString()).apply();
            } catch (Exception e) {
                Toast.makeText(c, e.getMessage(), Toast.LENGTH_SHORT).show();
            }
        }
        BusinessDocument newDocument(DocumentType type) {
            current = BusinessDocument.blank(type, makeNumber(type));
            current.colorTemplate = defaultColor;
            if (!issuers.isEmpty()) {
                IssuerProfile i = issuers.get(0);
                current.issuerName = i.name; current.issuerRegistration = i.registration; current.issuerContact = i.contact; current.issuerPhone = i.phone; current.issuerEmail = i.email; current.issuerAddress = i.address;
            }
            hasActiveDocument = true;
            return current;
        }
        String makeNumber(DocumentType type) {
            return type.prefix + "-" + new SimpleDateFormat("yyyyMMdd-HHmm", Locale.US).format(new Date());
        }
        void saveCurrent(Context c) {
            current.updatedAt = System.currentTimeMillis();
            rememberCustomerFromCurrent();
            rememberIssuerFromCurrent();
            int index = -1;
            for (int i = 0; i < documents.size(); i++) if (documents.get(i).id.equals(current.id)) index = i;
            if (index >= 0) documents.set(index, current.copy()); else documents.add(0, current.copy());
            sortDocuments();
            save(c);
        }
        void sortDocuments() { Collections.sort(documents, (a, b) -> Long.compare(b.updatedAt, a.updatedAt)); }
        void duplicate(BusinessDocument source) {
            BusinessDocument d = source.copy();
            d.id = UUID.randomUUID().toString(); d.number = makeNumber(d.type); d.updatedAt = System.currentTimeMillis();
            current = d; documents.add(0, d.copy()); sortDocuments();
        }
        void delete(String id) {
            moveToDeleted(Collections.singleton(id));
            current = documents.isEmpty() ? BusinessDocument.blank(DocumentType.INVOICE, makeNumber(DocumentType.INVOICE)) : documents.get(0).copy();
            hasActiveDocument = false;
        }
        void deleteProject(String id) {
            HashSet<String> ids = new HashSet<>();
            for (BusinessDocument d : documents) if (id.equals(d.projectId)) ids.add(d.id);
            moveToDeleted(ids);
        }
        void moveToDeleted(Set<String> ids) {
            if (ids == null || ids.isEmpty()) return;
            long now = System.currentTimeMillis();
            ArrayList<BusinessDocument> remaining = new ArrayList<>();
            for (BusinessDocument d : documents) {
                if (ids.contains(d.id)) {
                    DeletedDocumentRecord record = new DeletedDocumentRecord();
                    record.document = d.copy();
                    record.deletedAt = now;
                    deletedDocuments.add(0, record);
                } else {
                    remaining.add(d);
                }
            }
            documents = remaining;
            pruneDeletedDocuments();
        }
        void restoreDeleted(String recordId) {
            DeletedDocumentRecord target = null;
            for (DeletedDocumentRecord record : deletedDocuments) if (record.id.equals(recordId)) target = record;
            if (target == null) return;
            BusinessDocument restored = target.document.copy();
            restored.updatedAt = System.currentTimeMillis();
            boolean exists = false;
            for (BusinessDocument d : documents) if (d.id.equals(restored.id)) exists = true;
            if (!exists) documents.add(0, restored);
            deletedDocuments.removeIf(record -> record.id.equals(recordId));
            current = restored.copy();
            hasActiveDocument = true;
            sortDocuments();
        }
        void permanentlyDeleteDeleted(String recordId) { deletedDocuments.removeIf(record -> record.id.equals(recordId)); }
        void pruneDeletedDocuments() { deletedDocuments.removeIf(DeletedDocumentRecord::expired); }
        void clear() { documents.clear(); deletedDocuments.clear(); customers.clear(); issuers.clear(); products.clear(); templates.clear(); current = BusinessDocument.blank(DocumentType.INVOICE, makeNumber(DocumentType.INVOICE)); hasActiveDocument = false; }
        List<ProjectArchive> projects() {
            Map<String, ProjectArchive> map = new HashMap<>();
            for (BusinessDocument d : documents) {
                if (d.projectId == null || d.projectId.isEmpty()) continue;
                ProjectArchive p = map.get(d.projectId);
                if (p == null) {
                    p = new ProjectArchive();
                    p.id = d.projectId; p.name = d.projectName == null || d.projectName.isEmpty() ? d.customerName : d.projectName;
                    p.customerName = d.customerName;
                    p.direction = "VENDOR".equals(d.projectDirection) ? ProjectDirection.VENDOR : ProjectDirection.CUSTOMER;
                    map.put(p.id, p);
                }
                p.documents.add(d);
            }
            ArrayList<ProjectArchive> list = new ArrayList<>(map.values());
            Collections.sort(list, (a, b) -> Long.compare(maxUpdated(b.documents), maxUpdated(a.documents)));
            return list;
        }
        long maxUpdated(List<BusinessDocument> docs) { long v = 0; for (BusinessDocument d : docs) v = Math.max(v, d.updatedAt); return v; }
        void rememberCustomerFromCurrent() {
            if (current.customerName.trim().isEmpty()) return;
            CustomerProfile p = findCustomerByName(current.customerName);
            p.name = current.customerName; p.contact = current.customerContact; p.phone = current.customerPhone; p.email = current.customerEmail; p.address = current.customerAddress; p.updatedAt = System.currentTimeMillis();
            if (!customers.contains(p)) customers.add(0, p);
        }
        void rememberIssuerFromCurrent() {
            if (current.issuerName.trim().isEmpty()) return;
            IssuerProfile p = findIssuerByName(current.issuerName);
            p.name = current.issuerName; p.registration = current.issuerRegistration; p.contact = current.issuerContact; p.phone = current.issuerPhone; p.email = current.issuerEmail; p.address = current.issuerAddress; p.updatedAt = System.currentTimeMillis();
            if (!issuers.contains(p)) issuers.add(0, p);
        }
        void rememberProduct(LineItem line) {
            if (line.name.trim().isEmpty()) return;
            ProductProfile p = findProductByName(line.name);
            p.name = line.name; p.model = line.model; p.specification = line.specification; p.unitPrice = line.unitPrice; p.updatedAt = System.currentTimeMillis();
            if (!products.contains(p)) products.add(0, p);
        }
        CustomerProfile findCustomer(String id) { for (CustomerProfile p : customers) if (p.id.equals(id)) return p; return new CustomerProfile(); }
        IssuerProfile findIssuer(String id) { for (IssuerProfile p : issuers) if (p.id.equals(id)) return p; return new IssuerProfile(); }
        ProductProfile findProduct(String id) { for (ProductProfile p : products) if (p.id.equals(id)) return p; return new ProductProfile(); }
        TextTemplate findTemplate(String id) { for (TextTemplate p : templates) if (p.id.equals(id)) return p; return new TextTemplate(); }
        CustomerProfile findCustomerByName(String name) { for (CustomerProfile p : customers) if (p.name.equals(name)) return p; return new CustomerProfile(); }
        IssuerProfile findIssuerByName(String name) { for (IssuerProfile p : issuers) if (p.name.equals(name)) return p; return new IssuerProfile(); }
        ProductProfile findProductByName(String name) { for (ProductProfile p : products) if (p.name.equals(name)) return p; return new ProductProfile(); }
        int profileUsageCount(String kind, String id) {
            if ("customers".equals(kind)) return customerUsageCount(findCustomer(id));
            if ("products".equals(kind)) return productUsageCount(findProduct(id));
            return 0;
        }
        int customerUsageCount(CustomerProfile customer) {
            String name = normalizedProfileKey(customer.name);
            if (name.isEmpty()) return 0;
            int count = 0;
            for (BusinessDocument d : documents) if (normalizedProfileKey(d.customerName).equals(name)) count++;
            return count;
        }
        int productUsageCount(ProductProfile product) {
            String name = normalizedProfileKey(product.name);
            if (name.isEmpty()) return 0;
            String model = normalizedProfileKey(product.model);
            String specification = normalizedProfileKey(product.specification);
            int count = 0;
            for (BusinessDocument d : documents) {
                for (LineItem line : d.lines) {
                    if (!normalizedProfileKey(line.name).equals(name)) continue;
                    String lineModel = normalizedProfileKey(line.model);
                    String lineSpecification = normalizedProfileKey(line.specification);
                    if ((model.isEmpty() || model.equals(lineModel)) && (specification.isEmpty() || specification.equals(lineSpecification))) {
                        count++;
                        break;
                    }
                }
            }
            return count;
        }
        String normalizedProfileKey(String value) { return value == null ? "" : value.trim().toLowerCase(Locale.ROOT); }
        void upsertProfile(String kind, String id, Map<String, List<String>> v) {
            if ("customers".equals(kind)) {
                CustomerProfile p = findCustomer(id); p.name = first(v, "name", p.name); p.contact = first(v, "contact", p.contact); p.phone = first(v, "phone", p.phone); p.email = first(v, "email", p.email); p.address = first(v, "address", p.address); if (!customers.contains(p)) customers.add(0, p);
            } else if ("issuers".equals(kind)) {
                IssuerProfile p = findIssuer(id); p.name = first(v, "name", p.name); p.registration = first(v, "registration", p.registration); p.contact = first(v, "contact", p.contact); p.phone = first(v, "phone", p.phone); p.email = first(v, "email", p.email); p.address = first(v, "address", p.address); if (!issuers.contains(p)) issuers.add(0, p);
            } else if ("products".equals(kind)) {
                ProductProfile p = findProduct(id); p.name = first(v, "name", p.name); p.model = first(v, "model", p.model); p.specification = first(v, "specification", p.specification); p.unitPrice = parseDouble(first(v, "unitPrice", String.valueOf(p.unitPrice))); if (!products.contains(p)) products.add(0, p);
            } else {
                TextTemplate p = findTemplate(id); p.title = first(v, "title", p.title); p.kind = first(v, "kind", p.kind); p.content = first(v, "content", p.content); if (!templates.contains(p)) templates.add(0, p);
            }
        }
        void deleteProfile(String kind, String id) {
            if (id == null) return;
            if ("customers".equals(kind)) customers.removeIf(p -> p.id.equals(id));
            else if ("issuers".equals(kind)) issuers.removeIf(p -> p.id.equals(id));
            else if ("products".equals(kind)) products.removeIf(p -> p.id.equals(id));
            else templates.removeIf(p -> p.id.equals(id));
        }
        JSONObject toJson() throws JSONException {
            JSONObject o = new JSONObject();
            pruneDeletedDocuments();
            o.put("language", language.name()); o.put("pdfLanguage", pdfLanguage.name()); o.put("defaultColor", defaultColor.name()); o.put("current", current.toJson());
            JSONArray docs = new JSONArray(); for (BusinessDocument d : documents) docs.put(d.toJson()); o.put("documents", docs);
            JSONArray deleted = new JSONArray(); for (DeletedDocumentRecord record : deletedDocuments) deleted.put(record.toJson()); o.put("deletedDocuments", deleted);
            o.put("customers", profilesJson("customers")); o.put("issuers", profilesJson("issuers")); o.put("products", profilesJson("products")); o.put("templates", profilesJson("templates"));
            return o;
        }
        JSONArray profilesJson(String kind) throws JSONException {
            JSONArray a = new JSONArray();
            if ("customers".equals(kind)) for (CustomerProfile p : customers) { JSONObject o = new JSONObject(); o.put("id", p.id); o.put("name", p.name); o.put("contact", p.contact); o.put("phone", p.phone); o.put("email", p.email); o.put("address", p.address); a.put(o); }
            if ("issuers".equals(kind)) for (IssuerProfile p : issuers) { JSONObject o = new JSONObject(); o.put("id", p.id); o.put("name", p.name); o.put("registration", p.registration); o.put("contact", p.contact); o.put("phone", p.phone); o.put("email", p.email); o.put("address", p.address); a.put(o); }
            if ("products".equals(kind)) for (ProductProfile p : products) { JSONObject o = new JSONObject(); o.put("id", p.id); o.put("name", p.name); o.put("model", p.model); o.put("specification", p.specification); o.put("unitPrice", p.unitPrice); a.put(o); }
            if ("templates".equals(kind)) for (TextTemplate p : templates) { JSONObject o = new JSONObject(); o.put("id", p.id); o.put("kind", p.kind); o.put("title", p.title); o.put("content", p.content); a.put(o); }
            return a;
        }
        void fromJson(JSONObject o) {
            language = AppLanguage.fromStorage(o.optString("language", AppLanguage.systemDefault().name())); pdfLanguage = AppLanguage.fromStorage(o.optString("pdfLanguage", AppLanguage.systemDefault().name())); defaultColor = ColorTemplate.valueOf(o.optString("defaultColor", ColorTemplate.MONOCHROME.name()));
            current = BusinessDocument.fromJson(o.optJSONObject("current") == null ? new JSONObject() : o.optJSONObject("current"));
            if (current.type.isHidden()) current = BusinessDocument.blank(DocumentType.INVOICE, makeNumber(DocumentType.INVOICE));
            documents.clear(); JSONArray docs = o.optJSONArray("documents"); if (docs != null) for (int i = 0; i < docs.length(); i++) { BusinessDocument document = BusinessDocument.fromJson(docs.optJSONObject(i)); if (!document.type.isHidden()) documents.add(document); }
            deletedDocuments.clear(); JSONArray deleted = o.optJSONArray("deletedDocuments"); if (deleted != null) for (int i = 0; i < deleted.length(); i++) { DeletedDocumentRecord record = DeletedDocumentRecord.fromJson(deleted.optJSONObject(i)); if (!record.document.type.isHidden()) deletedDocuments.add(record); }
            readProfiles(o);
            sortDocuments();
            pruneDeletedDocuments();
        }
        void readProfiles(JSONObject root) {
            customers.clear(); issuers.clear(); products.clear(); templates.clear();
            JSONArray cs = root.optJSONArray("customers"); if (cs != null) for (int i = 0; i < cs.length(); i++) { JSONObject o = cs.optJSONObject(i); CustomerProfile p = new CustomerProfile(); p.id = o.optString("id", p.id); p.name = o.optString("name"); p.contact = o.optString("contact"); p.phone = o.optString("phone"); p.email = o.optString("email"); p.address = o.optString("address"); customers.add(p); }
            JSONArray is = root.optJSONArray("issuers"); if (is != null) for (int i = 0; i < is.length(); i++) { JSONObject o = is.optJSONObject(i); IssuerProfile p = new IssuerProfile(); p.id = o.optString("id", p.id); p.name = o.optString("name"); p.registration = o.optString("registration"); p.contact = o.optString("contact"); p.phone = o.optString("phone"); p.email = o.optString("email"); p.address = o.optString("address"); issuers.add(p); }
            JSONArray ps = root.optJSONArray("products"); if (ps != null) for (int i = 0; i < ps.length(); i++) { JSONObject o = ps.optJSONObject(i); ProductProfile p = new ProductProfile(); p.id = o.optString("id", p.id); p.name = o.optString("name"); p.model = o.optString("model"); p.specification = o.optString("specification"); p.unitPrice = o.optDouble("unitPrice"); products.add(p); }
            JSONArray ts = root.optJSONArray("templates"); if (ts != null) for (int i = 0; i < ts.length(); i++) { JSONObject o = ts.optJSONObject(i); TextTemplate p = new TextTemplate(); p.id = o.optString("id", p.id); p.kind = o.optString("kind"); p.title = o.optString("title"); p.content = o.optString("content"); templates.add(p); }
        }
    }

    static class PdfRenderer {
        static void draw(Canvas c, BusinessDocument d, AppLanguage lang, int width, int height, float scale) {
            c.save();
            c.scale(scale, scale);
            Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
            p.setColor(Color.WHITE); c.drawRect(0, 0, 595, 842, p);
            p.setColor(Color.BLACK); p.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD)); p.setTextSize(20);
            c.drawText(d.type.title(lang), 42, 58, p);
            p.setTypeface(Typeface.DEFAULT); p.setTextSize(11);
            c.drawText(d.type.subtitle(lang), 42, 78, p);
            p.setTextAlign(Paint.Align.RIGHT);
            c.drawText(local(lang, "番号", "编号", "No.") + " " + safeStatic(d.number), 553, 52, p);
            c.drawText(local(lang, "発行日", "开具日", "Issue") + " " + pdfDate(d.issueDate), 553, 70, p);
            c.drawText(local(lang, "取引日", "交易日", "Transaction") + " " + pdfDate(d.transactionDate), 553, 88, p);
            p.setTextAlign(Paint.Align.LEFT);
            p.setColor(d.colorTemplate.accent); p.setStrokeWidth(2); c.drawLine(42, 104, 553, 104, p);
            p.setColor(Color.BLACK); p.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD)); p.setTextSize(15);
            c.drawText((d.customerName.isEmpty() ? local(lang, "取引先名", "客户名称", "Customer") : d.customerName) + " " + d.honorific, 42, 138, p);
            p.setTypeface(Typeface.DEFAULT); p.setTextSize(10);
            drawMultiline(c, p, d.customerAddress, 42, 160, 230, 14);
            drawMultiline(c, p, d.customerContact + " " + d.customerPhone + " " + d.customerEmail, 42, 202, 230, 14);
            p.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD)); p.setTextSize(12);
            c.drawText(d.issuerName.isEmpty() ? local(lang, "発行者", "开具方", "Issuer") : d.issuerName, 375, 138, p);
            p.setTypeface(Typeface.DEFAULT); p.setTextSize(10);
            drawMultiline(c, p, d.issuerAddress + "\n" + d.issuerContact + " " + d.issuerPhone + " " + d.issuerEmail, 375, 160, 178, 14);
            if (d.type.showsLinePrices()) {
                p.setColor(Color.rgb(245, 247, 250)); c.drawRect(42, 240, 553, 296, p);
                p.setColor(Color.BLACK); p.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD)); p.setTextSize(12);
                c.drawText(d.type.totalLabel(lang), 56, 264, p);
                p.setTextAlign(Paint.Align.RIGHT); p.setTextSize(19); c.drawText(NumberFormat.getCurrencyInstance(Locale.JAPAN).format(d.displayTotal()), 535, 272, p); p.setTextAlign(Paint.Align.LEFT);
            }
            float y = d.type.showsLinePrices() ? 326 : 248;
            p.setColor(d.colorTemplate.accent); c.drawRect(42, y, 553, y + 24, p);
            p.setColor(Color.WHITE); p.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD)); p.setTextSize(10);
            c.drawText(local(lang, "品目", "品项", "Item"), 50, y + 16, p);
            c.drawText(local(lang, "数量", "数量", "Qty"), 350, y + 16, p);
            c.drawText(local(lang, "単価", "单价", "Unit"), 410, y + 16, p);
            c.drawText(local(lang, "金額", "金额", "Amount"), 485, y + 16, p);
            y += 24;
            p.setTypeface(Typeface.DEFAULT); p.setTextSize(9); p.setColor(Color.BLACK);
            for (LineItem line : d.lines) {
                c.drawRect(42, y, 553, y + 34, strokePaint(Color.rgb(215, 215, 212)));
                c.drawText(line.name.isEmpty() ? "-" : line.name, 50, y + 13, p);
                c.drawText((line.model + " " + line.specification).trim(), 50, y + 27, p);
                p.setTextAlign(Paint.Align.RIGHT);
                c.drawText(trimStatic(line.quantity), 385, y + 20, p);
                c.drawText(NumberFormat.getNumberInstance(Locale.JAPAN).format(line.unitPrice), 455, y + 20, p);
                c.drawText(NumberFormat.getNumberInstance(Locale.JAPAN).format(line.amount()), 540, y + 20, p);
                p.setTextAlign(Paint.Align.LEFT);
                y += 34;
                if (y > 690) break;
            }
            y += 20;
            p.setColor(Color.BLACK); p.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD)); p.setTextSize(11);
            c.drawText(local(lang, "備考", "备注", "Notes"), 42, y, p);
            p.setTypeface(Typeface.DEFAULT); p.setTextSize(10);
            drawMultiline(c, p, d.notes + "\n" + d.paymentDetails + "\n" + d.documentMemo, 42, y + 18, 300, 14);
            p.setTextAlign(Paint.Align.RIGHT);
            c.drawText("Shoko Forms", 553, 812, p);
            c.restore();
        }
        static Paint strokePaint(int color) { Paint p = new Paint(Paint.ANTI_ALIAS_FLAG); p.setStyle(Paint.Style.STROKE); p.setStrokeWidth(1); p.setColor(color); return p; }
        static void drawMultiline(Canvas c, Paint p, String text, float x, float y, float maxWidth, float lineHeight) {
            if (text == null) return;
            for (String line : text.split("\\n")) {
                if (line.length() > 36) line = line.substring(0, 36);
                c.drawText(line, x, y, p); y += lineHeight;
            }
        }
        static String pdfDate(long millis) { return new SimpleDateFormat("yyyy/MM/dd", Locale.US).format(new Date(millis)); }
    }

    static String safeStatic(String s) { return s == null ? "" : s; }
    static String trimStatic(double value) { return Math.abs(value - Math.round(value)) < 0.0001 ? String.valueOf((long) value) : String.valueOf(value); }

    static class Texts {
        static String t(String k, AppLanguage l) {
            Map<String, String[]> m = new HashMap<>();
            put(m, "home", "ホーム", "首页", "Home"); put(m, "create", "作成", "创建", "Create"); put(m, "preview", "プレビュー", "预览", "Preview"); put(m, "settings", "設定", "设置", "Settings");
            put(m, "documents", "帳票", "表单", "Forms"); put(m, "customerForms", "顧客向け帳票", "给客户的表单", "Customer Forms"); put(m, "vendorForms", "仕入先向け帳票", "给供应商的表单", "Vendor Forms");
            put(m, "androidAppSubtitle", "iOS版と同じ帳票ワークフローをAndroidに最適化", "将 iOS 版表单流程优化到 Android", "iOS form workflows adapted for Android"); put(m, "homeSubtitle", "最近のプロジェクト、帳票、マスターデータをここから操作します。", "从这里管理最近项目、表单与主档资料。", "Manage recent projects, forms, and master data from here.");
            put(m, "support", "サポート", "支持", "Support"); put(m, "supportMessage", "表單建立、PDF、備份、Google Play Pro 購買與資料管理問題，可先查看使用導覽。Email: service@niix.jp", "表单建立、PDF、备份、Google Play Pro 购买与资料管理问题，可先查看使用导览。Email: service@niix.jp", "For forms, PDF, backups, Google Play Pro, and data management, start with the guide. Email: service@niix.jp");
            put(m, "openGuide", "導覽を開く", "打开导览", "Open Guide"); put(m, "guideTitle", "使用導覽", "使用导览", "User Guide"); put(m, "guideMessage", "1. 公司、客戶、商品主檔可先建立。\n2. 選擇客戶或供應商流程建立表單。\n3. 保存後可預覽 PDF、匯出或使用 Pro 分享。\n4. 設定頁可切換語言、深色模式、配色與 Google Play Pro。", "1. 可先建立公司、客户、商品主档。\n2. 选择客户或供应商流程建立表单。\n3. 保存后可预览 PDF、导出或使用 Pro 分享。\n4. 设置页可切换语言、深色模式、配色与 Google Play Pro。", "1. Create company, customer, and product records first.\n2. Choose a customer or vendor workflow to create forms.\n3. Save, preview PDF, export, or share with Pro.\n4. Use Settings for language, dark mode, colors, and Google Play Pro.");
            put(m, "close", "閉じる", "关闭", "Close"); put(m, "showAllForms", "すべての帳票タイプを表示", "显示全部表单类型", "Show All Form Types");
            put(m, "recentProjects", "最近のプロジェクト", "最近项目", "Recent Projects"); put(m, "recentDocuments", "最近の帳票", "最近表单", "Recent Forms"); put(m, "noSavedProjects", "保存済みのプロジェクトはありません。", "没有已保存项目。", "No saved projects.");
            put(m, "noSavedDocuments", "保存済みなし", "没有已保存内容", "No saved forms"); put(m, "management", "管理", "管理", "Management"); put(m, "data", "データ", "数据", "Data");
            put(m, "customers", "取引先", "客户", "Customers"); put(m, "products", "商品", "商品", "Products"); put(m, "templates", "テンプレート", "模板", "Templates"); put(m, "company", "会社情報", "公司信息", "Company");
            put(m, "save", "保存", "保存", "Save"); put(m, "saved", "保存済み", "已保存", "Saved"); put(m, "saveComplete", "保存が完了しました。", "保存完成。", "Saved."); put(m, "edit", "編集", "编辑", "Edit"); put(m, "delete", "削除", "删除", "Delete"); put(m, "duplicate", "複製", "复制", "Duplicate");
            put(m, "cancel", "キャンセル", "取消", "Cancel"); put(m, "add", "追加", "添加", "Add"); put(m, "share", "共有", "分享", "Share"); put(m, "deleteConfirm", "削除済みに移動します。30日以内なら復元できます。", "将移到已删除项目。30 天内可以恢复。", "Move this item to Deleted Files? You can restore it within 30 days.");
            put(m, "number", "番号", "编号", "Number"); put(m, "relatedNumber", "関連番号", "关联编号", "Reference No."); put(m, "issueDate", "発行日", "开具日", "Issue Date"); put(m, "transactionDate", "取引日", "交易日", "Transaction Date"); put(m, "dueDate", "支払期日", "付款期限", "Due Date");
            put(m, "project", "プロジェクト", "项目", "Project"); put(m, "businessPartner", "取引先", "交易对象", "Business Partner"); put(m, "issuer", "発行者", "开具方", "Issuer"); put(m, "customerName", "取引先名", "客户名称", "Customer Name"); put(m, "issuerName", "発行者名", "开具方名称", "Issuer Name");
            put(m, "contact", "担当者", "联系人", "Contact"); put(m, "phone", "電話", "电话", "Phone"); put(m, "email", "メール", "邮箱", "Email"); put(m, "address", "住所", "地址", "Address"); put(m, "registration", "登録番号", "登记编号", "Registration");
            put(m, "lineItems", "明細", "明细", "Line Items"); put(m, "itemName", "品目", "品项", "Item"); put(m, "model", "型番", "型号", "Model"); put(m, "specification", "仕様", "规格", "Specification"); put(m, "quantity", "数量", "数量", "Quantity"); put(m, "unitPrice", "単価", "单价", "Unit Price"); put(m, "addLine", "明細を追加", "添加明细", "Add Line");
            put(m, "notes", "備考", "备注", "Notes"); put(m, "paymentDetails", "振込口座", "汇款账户", "Payment Details"); put(m, "terms", "条件", "条件", "Terms"); put(m, "attachments", "添付ファイル", "附件", "Attachments"); put(m, "addAttachment", "添付を追加", "添加附件", "Add Attachment");
            put(m, "paymentProof", "支払証明", "支付证明", "Payment Proof"); put(m, "paymentDate", "支払日時", "支付时间", "Payment Date"); put(m, "paymentAmount", "支払金額", "支付金额", "Payment Amount");
            put(m, "pdfPreview", "PDFプレビュー", "PDF 预览", "PDF Preview"); put(m, "savePDF", "PDF保存", "保存 PDF", "Save PDF"); put(m, "pdfExportError", "PDFを書き出せませんでした。", "无法导出 PDF。", "Could not export PDF.");
            put(m, "zoomIn", "拡大", "放大", "Zoom In"); put(m, "zoomOut", "縮小", "缩小", "Zoom Out"); put(m, "fitWidth", "幅に合わせる", "适合宽度", "Fit Width");
            put(m, "projects", "プロジェクト", "项目", "Projects"); put(m, "newCustomerProject", "顧客プロジェクト作成", "创建客户项目", "New Customer Project"); put(m, "newVendorProject", "仕入先プロジェクト作成", "创建供应商项目", "New Vendor Project");
            put(m, "deletedFiles", "削除済みファイル", "已删除文件", "Deleted Files"); put(m, "noDeletedFiles", "削除済みファイルはありません。", "没有已删除文件。", "No deleted files."); put(m, "deleteHistoryMessage", "削除した帳票は30日間ここに保存され、その後自動削除されます。", "删除的表单会在这里保留 30 天，之后自动删除。", "Deleted forms stay here for 30 days, then are removed automatically.");
            put(m, "restore", "復元", "恢复", "Restore"); put(m, "permanentDelete", "完全削除", "永久删除", "Delete Permanently"); put(m, "deletedAt", "削除日", "删除日期", "Deleted"); put(m, "expiresAt", "自動削除日", "自动删除日期", "Expires"); put(m, "documentRestoreComplete", "帳票を復元しました。", "已恢复表单。", "Form restored."); put(m, "permanentDeleteConfirm", "完全に削除します。この操作は取り消せません。", "将永久删除。此操作无法撤销。", "Delete permanently? This cannot be undone.");
            put(m, "exportBackup", "バックアップを書き出し", "导出备份", "Export Backup"); put(m, "importBackup", "バックアップを読み込み", "导入备份", "Import Backup"); put(m, "importForm", "帳票ファイルを読み込み", "导入表单文件", "Import Form"); put(m, "importError", "読み込めませんでした。", "无法导入。", "Could not import.");
            put(m, "externalImportTitle", "Shokoへ取り込み", "导入到 Shoko", "Import to Shoko"); put(m, "externalImportMessage", "写真またはPDFを取り込むプロジェクト区分を選択してください。", "请选择照片或 PDF 要导入的项目分类。", "Choose the project direction for these photos or PDF.");
            put(m, "externalImportProject", "取り込み先プロジェクト", "导入到哪个项目", "Import Destination Project"); put(m, "externalImportForm", "取り込み先帳票", "导入到哪个表单", "Import Destination Form"); put(m, "externalImportDone", "ファイルを帳票へ取り込みました。", "已导入文件到表单。", "Files imported to the form.");
            put(m, "newProject", "新規プロジェクト", "新项目", "New Project"); put(m, "pdfSingleOnly", "PDFは一度に1件だけ取り込めます。", "PDF 一次只能导入一个。", "Only one PDF can be imported at a time.");
            put(m, "clearData", "ローカルデータ削除", "清除本地数据", "Clear Local Data"); put(m, "clearDataConfirm", "すべてのローカルデータを削除します。", "将删除所有本地数据。", "Delete all local data?");
            put(m, "interfaceLanguage", "操作画面の言語", "操作界面语言", "Interface Language"); put(m, "pdfLanguage", "PDF帳票の言語", "PDF 表单语言", "PDF Language"); put(m, "darkMode", "ダークモード", "深色模式", "Dark Mode"); put(m, "tableColor", "帳票配色", "表格配色", "Table Color");
            put(m, "proPlan", "Shoko Pro", "Shoko Pro", "Shoko Pro"); put(m, "proActive", "Pro機能が有効です。", "Pro 功能已启用。", "Pro features are active."); put(m, "proInactive", "Google Play で Pro を購入すると共有機能を利用できます。", "通过 Google Play 购买 Pro 后可使用分享功能。", "Buy Pro through Google Play to use sharing features.");
            put(m, "buyMonthly", "月額プランを購入", "购买月费方案", "Buy Monthly"); put(m, "buyYearly", "年額プランを購入", "购买年费方案", "Buy Yearly"); put(m, "restorePurchases", "購入を復元", "恢复购买", "Restore Purchases");
            put(m, "purchaseComplete", "購入が完了しました。", "购买已完成。", "Purchase complete."); put(m, "purchaseCancelled", "購入をキャンセルしました。", "已取消购买。", "Purchase cancelled."); put(m, "purchaseFailed", "購入を完了できませんでした。", "无法完成购买。", "Purchase failed."); put(m, "purchasePending", "購入処理中です。", "购买处理中。", "Purchase pending.");
            put(m, "restoreComplete", "購入を復元しました。", "已恢复购买。", "Purchases restored."); put(m, "restoreEmpty", "復元できる購入はありません。", "没有可恢复的购买。", "No purchases to restore."); put(m, "restoreFailed", "購入を復元できませんでした。", "无法恢复购买。", "Could not restore purchases.");
            put(m, "billingNotReady", "Google Play に接続中です。もう一度お試しください。", "正在连接 Google Play，请稍后再试。", "Connecting to Google Play. Try again shortly."); put(m, "productUnavailable", "Google Play 商品を取得できませんでした。", "无法取得 Google Play 商品。", "Google Play product is unavailable.");
            put(m, "proRequiredTitle", "Pro機能です", "这是 Pro 功能", "Pro Feature"); put(m, "proShareMessage", "PDF共有には Shoko Pro が必要です。Google Play で購入または復元してください。", "PDF 分享需要 Shoko Pro。请通过 Google Play 购买或恢复。", "PDF sharing requires Shoko Pro. Buy or restore through Google Play."); put(m, "openPro", "Pro設定へ", "前往 Pro 设置", "Open Pro");
            put(m, "androidBillingNote", "Google Play Console で subscription 商品 ID monthly / yearly（必要なら annual）を作成し、このアプリのパッケージ名で公開テストまたは本番配信してください。", "请在 Google Play Console 建立订阅商品 ID monthly / yearly（需要时 annual），并使用此 App 包名进行测试或正式发布。", "Create subscription product IDs monthly / yearly (and annual if needed) in Google Play Console for this app package before testing or release.");
            put(m, "rememberProduct", "商品として保存", "保存为商品", "Save as Product"); put(m, "name", "名称", "名称", "Name"); put(m, "title", "タイトル", "标题", "Title"); put(m, "type", "種類", "类型", "Type"); put(m, "content", "内容", "内容", "Content");
            put(m, "profileUsedTitle", "保存済み帳票で使用中です", "此资料已被已保存表单使用", "Used by Saved Forms"); put(m, "profileUsedSaveMessage", "{count}件の保存済み帳票で使われています。候補資料を更新しても完成済み帳票は自動で書き換えられません。", "目前有 {count} 份已保存表单使用这笔资料。更新候选资料不会自动改写已完成表单。", "{count} saved forms use this candidate. Updating it does not automatically rewrite completed forms.");
            put(m, "profileUsedDeleteMessage", "{count}件の保存済み帳票で使われています。候補資料を削除しても完成済み帳票は残ります。削除しますか？", "目前有 {count} 份已保存表单使用这笔资料。删除候选资料不会删除已完成表单。仍要删除吗？", "{count} saved forms use this candidate. Deleting it will not delete completed forms. Delete it?");
            put(m, "updateExisting", "既存データを更新", "更新现有资料", "Update Existing Data");
            String[] v = m.get(k);
            if (v == null) return k;
            return isChinese(l) ? v[1] : (l == AppLanguage.ENGLISH || l == AppLanguage.KOREAN || l == AppLanguage.NEPALI || l == AppLanguage.FRENCH || l == AppLanguage.VIETNAMESE) ? v[2] : v[0];
        }
        static void put(Map<String, String[]> m, String k, String ja, String zh, String en) { m.put(k, new String[]{ja, zh, en}); }
    }
}
