#ifndef BMDBDIALOG_H
#define BMDBDIALOG_H

#include <memory>
#include <QDialog>
#include <QSqlTableModel>
#include <QSqlDatabase>
#include "dlgdbupdate.h"


namespace Ui {
class BmDbDialog;
}

class BmDbDialog : public QDialog
{
    Q_OBJECT
    
public:
    explicit BmDbDialog(QWidget *parent = nullptr);
    ~BmDbDialog() override;

private slots:
    void pushButtonAddClicked();
    void pushButtonUpdateAllClicked();
    void pushButtonClearDbClicked();
    void pushButtonDeleteClicked();
    void pushButtonUpdateClicked();

signals:
    void bmDbAboutToUpdate();
    void bmDbUpdated();
    void bmDbCleared();

private:
    std::unique_ptr<Ui::BmDbDialog> ui;
    QSqlTableModel m_pathsModel;
    DlgDbUpdate m_dbUpdateDlg{this};
};

#endif // BMDBDIALOG_H
